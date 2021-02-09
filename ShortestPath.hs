-- By Sorrowful T-Rex; https://github.com/sorrowfulT-Rex/Haskell-Graphs.

module ShortestPath where

import           Control.Monad
import           Control.Monad.Trans.State
import           Data.Either (Either(..))
import           Data.List (minimumBy)
import           Data.Maybe

-- Requires installation
import           Data.IntMap.Lazy as IM 
 (IntMap(..), notMember, delete, insert, empty, fromList, keys, null, (!), (!?))
import           Data.Set as S (fromList, insert, member)

import           Graph
import           Utilities

infinity :: Int
infinity = maxBound

-- Returns an IntMap of nodes reachable from the given root and their distances.
-- Pre: The root is in the graph.
shortestDistances :: (Graph a) => Int -> a -> IntMap Int
shortestDistances n graph
  = execState (dijkstraS n graph sp) empty
  where
    sp _ n d = do
      acc <- get
      put $ IM.insert n d acc

-- Returns the shortest distance between two nodes, or Nothing if disconnected.
-- Pre: The nodes are in the graph.
shortestDistance :: (Graph a) => Int -> Int -> a -> Maybe Int
shortestDistance n n' graph
  = (execState (dijkstraS n graph sp) empty) !? n'
  where
    sp _ n d = do
      acc <- get
      put $ IM.insert n d acc
      breakUpon (n' == n)

-- A State that simulates Dijkstra's Algorithm.
-- This function is convoluted and is not necessary unless you need to do custom
-- actions during the formation of the shortest path spanning tree.
-- See full documentation in README.md. (TODO)
-- Pre: The graph contains no negative cycles.
dijkstraS :: (Graph a, Flaggable l) 
  => Int 
  -> a 
  -> (Int -> Int -> Int -> State b l) 
  -> State b ()
dijkstraS root graph fun = do
  t <- get
  let (_, res) = execState dijsktra' ((S.fromList [root], initAdj), t)
  put res
  where
    initAdj   = execState (forM_ (neighbours root graph) $ \s -> 
      get >>= put . IM.insert s (fromJust (weight (root, s) graph), root)
      ) empty
    dijsktra' = loop_ $ do
      ((v, f), t) <- get
      breakWhen (IM.null f) $ do
        let minN     = minimumBy ((. (f !)) . compare . (f !)) (keys f)
        let (d, n)   = f ! minN
        let adj      = neighbours minN graph
        let v'       = S.insert minN v
        let (b', t') = runState (fun n minN d) t
        put ((v', execState (forM_ adj $ \s -> do
          fringe <- get
          let newW = fromJust $ weight (minN, s) graph
          continueWhen (S.member s v') $ if IM.notMember s fringe
            then put $ IM.insert s (d + newW, minN) fringe
            else put $ IM.insert s (min (fringe ! s) (d + newW, minN)) fringe
          ) $ delete minN f), t')
        return b'
