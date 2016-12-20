{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE TypeOperators         #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE EmptyDataDecls        #-}
module Grenade.Recurrent.Core.Network (
    Recurrent
  , FeedForward
  , RecurrentLayer (..)
  , RecurrentUpdateLayer (..)
  , RecurrentNetwork (..)
  , RecurrentInputs (..)
  , CreatableRecurrent (..)
  ) where


import           Control.Monad.Random ( MonadRandom )
import           Data.Singletons ( SingI )

import           Grenade.Core.Shape
import           Grenade.Core.Network


-- | Witness type to say indicate we're building up with a normal feed
--   forward layer.
data FeedForward :: * -> *
-- | Witness type to say indicate we're building up with a recurrent layer.
data Recurrent :: * -> *

-- | Class for a recurrent layer.
--   It's quite similar to a normal layer but for the input and output
--   of an extra recurrent data shape.
class UpdateLayer x => RecurrentUpdateLayer x where
  -- | Shape of data that is passed between each subsequent run of the layer
  type RecurrentShape x   :: Shape

class (RecurrentUpdateLayer x, SingI (RecurrentShape x)) => RecurrentLayer x (i :: Shape) (o :: Shape) where
  -- | Used in training and scoring. Take the input from the previous
  --   layer, and give the output from this layer.
  runRecurrentForwards    :: x -> S (RecurrentShape x) -> S i -> (S (RecurrentShape x), S o)
  -- | Back propagate a step. Takes the current layer, the input that the
  --   layer gave from the input and the back propagated derivatives from
  --   the layer above.
  --   Returns the gradient layer and the derivatives to push back further.
  runRecurrentBackwards   :: x -> S (RecurrentShape x) -> S i -> S (RecurrentShape x) -> S o -> (Gradient x, S (RecurrentShape x), S i)

data RecurrentNetwork :: [*] -> [Shape] -> * where
  OR     :: (SingI i, SingI o, Layer x i o) => !x -> RecurrentNetwork '[FeedForward x] '[i, o]
  (:~~>) :: (SingI i, Layer x i h)          => !x -> !(RecurrentNetwork xs (h ': hs)) -> RecurrentNetwork (FeedForward x ': xs) (i ': h ': hs)
  (:~@>) :: (SingI i, RecurrentLayer x i h) => !x -> !(RecurrentNetwork xs (h ': hs)) -> RecurrentNetwork (Recurrent x ': xs) (i ': h ': hs)
infixr 5 :~~>
infixr 5 :~@>

instance Show (RecurrentNetwork l h) where
  show (OR a) = "OR " ++ show a
  show (i :~~> o) = show i ++ "\n:~~>\n" ++ show o
  show (i :~@> o) = show i ++ "\n:~@>\n" ++ show o


-- | Recurrent inputs (sideways shapes on an imaginary unrolled graph)
--   Parameterised on the layers of a Network.
data RecurrentInputs :: [*] -> * where
   ORS     :: UpdateLayer x
           => ()                   -> RecurrentInputs '[FeedForward x]
   (:~~+>) :: UpdateLayer x
           => ()                   -> !(RecurrentInputs xs) -> RecurrentInputs (FeedForward x ': xs)
   (:~@+>) :: (SingI (RecurrentShape x), RecurrentUpdateLayer x)
           => !(S (RecurrentShape x)) -> !(RecurrentInputs xs) -> RecurrentInputs (Recurrent x ': xs)
infixr 5 :~~+>
infixr 5 :~@+>

-- | A network can easily be created by hand with (:~~>) and (:~@>), but an easy way to initialise a random
--   recurrent network and a set of random inputs for it is with the randomRecurrent.
class CreatableRecurrent (xs :: [*]) (ss :: [Shape]) where
  -- | Create a network of the types requested
  randomRecurrent :: MonadRandom m => m (RecurrentNetwork xs ss, RecurrentInputs xs)

instance (SingI i, SingI o, Layer x i o) => CreatableRecurrent (FeedForward x ': '[]) (i ': o ': '[]) where
  randomRecurrent = do
    thisLayer <- createRandom
    return (OR thisLayer, ORS ())

instance (SingI i, Layer x i o, CreatableRecurrent xs (o ': r ': rs)) => CreatableRecurrent (FeedForward x ': xs) (i ': o ': r ': rs) where
  randomRecurrent = do
    thisLayer     <- createRandom
    (rest, resti) <- randomRecurrent
    return (thisLayer :~~> rest, () :~~+> resti)

instance (SingI i, RecurrentLayer x i o, CreatableRecurrent xs (o ': r ': rs)) => CreatableRecurrent (Recurrent x ': xs) (i ': o ': r ': rs) where
  randomRecurrent = do
    thisLayer     <- createRandom
    thisShape     <- randomOfShape
    (rest, resti) <- randomRecurrent
    return (thisLayer :~@> rest, thisShape :~@+> resti)

