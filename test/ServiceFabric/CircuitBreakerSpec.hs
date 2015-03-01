{-# LANGUAGE OverloadedStrings, DeriveDataTypeable, ScopedTypeVariables #-}

module ServiceFabric.CircuitBreakerSpec where

import Data.Traversable
import Data.Typeable
import ServiceFabric.CircuitBreaker
import Test.Hspec
import Data.IORef
import Test.QuickCheck
import Control.Exception.Base hiding (throw, try)
import Control.Monad.CatchIO

data CircuitBreakerTestException = CircuitBreakerTestException deriving (Eq, Show, Typeable)
instance Exception CircuitBreakerTestException

requests :: [Int]
requests = [1..10]

spec :: Spec
spec = do
  describe "circuitBreaker" $ do
    it "Multiple failures prevent subsequent calls" $ do
      property $ \failureMax -> do
        let positiveFailureMax      = (abs failureMax) `mod` 5
        let options                 = defaultCircuitBreakerOptions { maxBreakerFailures = positiveFailureMax }
        ref                         <- newIORef (0 :: Int)
        let service _               = atomicModifyIORef' ref (\c -> (c + 1, ())) >> throw CircuitBreakerTestException :: IO Int
        (_, circuitBreakerService)  <- circuitBreaker options service
        results                     <- traverse (\req -> try $ try $ circuitBreakerService req) requests :: IO [Either CircuitBreakerException (Either CircuitBreakerTestException Int)]
        let expectedResults         = (replicate (positiveFailureMax + 1) (Right $ Left $ CircuitBreakerTestException)) ++ (replicate (10 - positiveFailureMax - 1) (Left $ CircuitBreakerException "Circuit breaker open."))
        results `shouldBe` expectedResults
        (readIORef ref) `shouldReturn` (positiveFailureMax + 1)
        


