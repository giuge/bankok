{-# LANGUAGE OverloadedStrings #-}

module Lib where

-- base
import System.Exit as Exit
import System.IO
import Debug.Trace

import Data.List hiding (null)
import Data.List.Split (chunksOf, endBy, splitWhen)
import Data.Text (null, unpack, toTitle, splitOn, Text)
import qualified Data.Text.Encoding as Text

import Data.Time
import Text.Printf
import Data.Char (isDigit, toUpper)

import Control.Exception (IOException)
import qualified Control.Exception as Exception

-- bytes
import Data.ByteString.Lazy (ByteString)
import qualified Data.ByteString.Lazy as ByteString

-- cassava
import Data.Csv (FromNamedRecord (parseNamedRecord), (.:))
import qualified Data.Csv as CSV

-- vector
import Data.Vector (Vector)
import qualified Data.Vector as V

import CLI

data Input =
  Input
    {
      iDate            :: !Text
    , iCurrencyDate    :: !Text
    , iEarned          :: Text
    , iSpent           :: Text
    , iDescription     :: !Text
    , iFullDescription :: !Text
    }
  deriving (Eq, Show)

instance FromNamedRecord Input where
  parseNamedRecord m =
    Input
      <$> m .: "Data Operazione"
      <*> m .: "Data Valuta"
      <*> m .: "Entrate"
      <*> m .: "Uscite"
      <*> m .: "Descrizione"
      <*> fmap Text.decodeLatin1 (m .: "Descrizione Completa")

data TransactionType = Expenses | Income
  deriving(Eq, Show)


decodeItems :: ByteString -> Either String (Vector Input)
decodeItems = fmap snd . CSV.decodeByName

decodeItemsFromFile :: FilePath -> IO (Either String (Vector Input))
decodeItemsFromFile filePath =
  either Left decodeItems <$> catchShowIO (ByteString.readFile filePath)


formatAmount :: Text -> String
formatAmount amount = printf "%.2f" (read (unpack amount) :: Float)

toLedgerFormat :: Input -> [[String]] -> String
toLedgerFormat input ldgEntries =
  date ++ " * " ++ description ++ "\n  " ++ trxDetails ++ "\n  Assets:Checking\n\n"
  where
    parseDate =
      parseTimeOrError True defaultTimeLocale "%d/%m/%Y" (unpack (iDate input)) :: UTCTime
    date =
      formatTime defaultTimeLocale "%Y/%m/%d" parseDate
    description =
      unpack $ toTitle $ Prelude.head $ splitOn "   " $ iFullDescription input
    separator =
      "\t\t\t\t\t\t"
    trxDetails =
      if Data.Text.null (iEarned input)
         then findCategory Expenses description ldgEntries ++ separator ++ "€" ++ formatAmount (iSpent input)
         else findCategory Income description ldgEntries ++ separator ++ "-€" ++ formatAmount (iEarned input)


catchShowIO :: IO a -> IO (Either String a)
catchShowIO action =
  fmap Right action `Exception.catch` handleIOException
  where
    handleIOException :: IOException -> IO (Either String a)
    handleIOException = return . Left . show


sortByDate :: String -> String -> Ordering
sortByDate a b = parseDateA `compare` parseDateB
  where
    parseDateA =
      parseTimeOrError True defaultTimeLocale "%Y/%m/%d" (head $ words a) :: UTCTime
    parseDateB =
      parseTimeOrError True defaultTimeLocale "%Y/%m/%d" (head $ words b) :: UTCTime


getHeader :: IO String
getHeader = do
  date <- head . words . show <$> getCurrentTime
  return $ ";-- Generated by bankok (" ++ date ++ ") -- ;\n\n"


findCategory :: TransactionType -> String -> [[String]] -> String
findCategory trxType _ [] = show trxType
findCategory trxType d (x:xs) =
  if desc `isInfixOf` payee || desc == payee
     then head $ words $ x!!1
     else findCategory trxType d xs
  where
    desc = map toUpper d
    payee = map toUpper (head x)


parseLedgerFormat :: String -> [[String]]
parseLedgerFormat s = formatted
  where
    formatted =
      tail
      $ filter (not . Prelude.null)
      $ splitWhen Prelude.null
      $ lines s


run :: Args -> IO()
run (Args inputFile outputFile) = do
  eitherInput <- decodeItemsFromFile inputFile
  eitherJournal <- readFile "/home/giuge/ledger/journal.ldg"
  header <- getHeader
  case eitherInput of
    Left reason -> Exit.die reason
    Right input ->
     appendFile outputFile
     $ (++) header
     $ concat
     $ sortBy sortByDate
     $ V.toList
     $ toLedgerFormat <$> input <*> pure (parseLedgerFormat eitherJournal)
