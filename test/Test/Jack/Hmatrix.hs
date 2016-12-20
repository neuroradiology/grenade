{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE ScopedTypeVariables   #-}

module Test.Jack.Hmatrix where

import           Disorder.Jack

import           GHC.TypeLits

import qualified Numeric.LinearAlgebra.Static as HStatic

randomVector :: forall n. KnownNat n => Jack (HStatic.R n)
randomVector = (\s -> HStatic.randomVector s HStatic.Uniform * 2 - 1) <$> sizedNat

uniformSample :: forall m n. (KnownNat m, KnownNat n) => Jack (HStatic.L m n)
uniformSample = (\s -> HStatic.uniformSample s (-1) 1 ) <$> sizedNat
