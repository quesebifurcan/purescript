-----------------------------------------------------------------------------
--
-- Module      :  Language.PureScript.Parser.State
-- Copyright   :  (c) Phil Freeman 2013
-- License     :  MIT
--
-- Maintainer  :  Phil Freeman <paf31@cantab.net>
-- Stability   :  experimental
-- Portability :
--
-- |
--
-----------------------------------------------------------------------------

module Language.PureScript.Parser.State where

import Language.PureScript.Names
import Language.PureScript.Declarations

import qualified Text.Parsec as P
import qualified Data.Map as M

data ParseState = ParseState
  { indentationLevel :: P.Column } deriving Show


