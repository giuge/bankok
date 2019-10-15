module CLI where

import Options.Applicative
import Data.Semigroup ((<>))

data Args =
  Args
    { input  :: String
    , output :: String
    }

args :: Parser Args
args =
  Args
    <$> strOption
      (  long "input"
      <> short 'i'
      <> help "Your bank CSV file path."
      )
    <*> strOption
      (  long "output"
      <> short 'o'
      <> help "The output file path."
      )
