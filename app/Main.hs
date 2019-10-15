module Main where

import Lib
import CLI

import Options.Applicative
import Data.Semigroup ((<>))

main :: IO ()
main =
  run =<< execParser opts
  where
    opts = info (args <**> helper)
      (
         fullDesc
      <> progDesc "bankok -i ~/bank.csv -o ~/output.ldg"
      <> header "Converts a Fineco CSV file to ledger format."
      )
