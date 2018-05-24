-- |
-- Module      : Data.PostgreSQL.NetworkAddress
-- Copyright   : 2015-2018 Kei Hibino
-- License     : BSD3
--
-- Maintainer  : ex8k.hibino@gmail.com
-- Stability   : experimental
-- Portability : unknown
--
-- This module defines network-address types of PostgreSQL.
-- http://www.postgresql.org/docs/current/static/datatype-net-types.html
module Data.PostgreSQL.NetworkAddress
       (
         Inet (..), Cidr (..), cidr4', cidr4, cidr6', cidr6,
         NetAddress (..), netAddress4, netAddress6,
         V4HostAddress (..), v4HostAddressOctets,
         V6HostAddress (..), v6HostAddressLong, v6HostAddressWords,
         v6HostAddress, v6HostAddressL, v6HostAddressR,
       ) where

import Control.Applicative (pure)
import Control.Monad (guard)
import Data.Word (Word8, Word16, Word32)
import Data.Bits (shiftL, shiftR, (.&.), (.|.))


-- | Host address type along with IPv4 address string.
data V4HostAddress =
  V4HostAddress !Word8 !Word8 !Word8 !Word8
  deriving (Eq, Ord, Show, Read)

v4HostAddressOctets :: V4HostAddress -> (Word8, Word8, Word8, Word8)
v4HostAddressOctets (V4HostAddress a b c d) = (a, b, c, d)


-- | Host address type along with IPv6 address string.
--   Each 'Word16' value is host byte order.
--   Host byte order is portable in programs on its own host.
--   Network byte order is only needed, when communicating other hosts.
data V6HostAddress =
  V6HostAddress !Word16 !Word16 !Word16 !Word16 !Word16 !Word16 !Word16 !Word16
  deriving (Eq, Ord, Show, Read)

v6HostAddressLong :: Word16 -> Word16 -> Word16 -> Word16
                  -> Word16 -> Word16 -> Word16 -> Word16
                  -> V6HostAddress
v6HostAddressLong = V6HostAddress

v6HostAddress :: [Word16] -> [Word16] -> Maybe V6HostAddress
v6HostAddress ls rs  = do
  let zlength = 8 {- v6 length -} - length (ls ++ rs)
  guard $ zlength >= 0
  [a, b, c, d, e, f, g, h]  <-  pure $ ls ++ replicate zlength 0 ++ rs
  pure $ v6HostAddressLong a b c d e f g h

v6HostAddressR :: [Word16] -> Maybe V6HostAddress
v6HostAddressR = v6HostAddress []

v6HostAddressL :: [Word16] -> Maybe V6HostAddress
v6HostAddressL ls = v6HostAddress ls []

v6HostAddressWords :: V6HostAddress -> (Word16, Word16, Word16, Word16, Word16, Word16, Word16, Word16)
v6HostAddressWords (V6HostAddress a b c d e f g h) =
  (a, b, c, d, e, f, g, h)


data NetAddress
  = NetAddress4 !V4HostAddress !Word8
  | NetAddress6 !V6HostAddress !Word8
  deriving (Eq, Ord, Show, Read)

vmask4 :: (Ord a, Integral a) => a -> Bool
vmask4 = (<= 32)

netAddress4 :: V4HostAddress -> Word8 -> Maybe NetAddress
netAddress4 a4 m
  | vmask4 m   =  Just $ NetAddress4 a4 m
  | otherwise  =  Nothing

vmask6 :: (Ord a, Integral a) => a -> Bool
vmask6 = (<= 128)

netAddress6 :: V6HostAddress -> Word8 -> Maybe NetAddress
netAddress6 a6 m
  | vmask6 m   =  Just $ NetAddress6 a6 m
  | otherwise  =  Nothing

newtype Inet = Inet NetAddress  deriving (Eq, Ord, Show, Read)

newtype Cidr = Cidr NetAddress  deriving (Eq, Ord, Show, Read)

maskCidr4 :: V4HostAddress -> Word8 -> (Word32, Word32)
maskCidr4 (V4HostAddress w0 w1 w2 w3) m =
    (a4 .&. (1 `shiftL` mi - 1) `shiftL` (32 - mi), a4)
  where
    mi = fromIntegral m
    a4 :: Word32
    a4 = foldr (.|.) 0 $ zipWith
         (\w x -> fromIntegral w `shiftL` x)
         [w3, w2, w1, w0]
         [0,8 ..]

cidr4' :: V4HostAddress -> Word8 -> Maybe Cidr
cidr4' ha0 m = do
    guard $ vmask4 m
    let (ra, _) = maskCidr4 ha0 m
        ha = fromList4 $ map (byte . (ra `shiftR`)) [24,16,8,0]
    return . Cidr $ NetAddress4 ha m
  where
    byte = fromIntegral . (.&. 0xff)
    fromList4 ws = V4HostAddress w0 w1 w2 w3
      where [w0, w1, w2, w3] = ws

cidr4 :: V4HostAddress -> Word8 -> Maybe Cidr
cidr4 ha m = do
  na <- netAddress4 ha m
  let (ma, ra) = maskCidr4 ha m
  guard $ ma == ra
  return $ Cidr na

maskCidr6 :: V6HostAddress -> Word8 -> (Integer, Integer)
maskCidr6 (V6HostAddress w0 w1 w2 w3 w4 w5 w6 w7) m =
    (a6 .&. (1 `shiftL` mi - 1) `shiftL` (128 - mi), a6)
  where
    mi = fromIntegral m
    a6 :: Integer
    a6 = foldr (.|.) 0 $ zipWith
         (\w x -> fromIntegral w `shiftL` x)
         [w7, w6, w5, w4, w3, w2, w1, w0]
         [0,16 ..]

cidr6' :: V6HostAddress -> Word8 -> Maybe Cidr
cidr6' ha0 m = do
    guard $ vmask6 m
    let (ra, _) = maskCidr6 ha0 m
        ha = fromList6 $ map (word . (ra `shiftR`)) [112, 96 .. 0]
    return . Cidr $ NetAddress6 ha m
  where
    word = fromIntegral . (.&. 0xffff)
    fromList6 ws = V6HostAddress w0 w1 w2 w3 w4 w5 w6 w7
      where [w0, w1, w2, w3, w4, w5, w6, w7] = ws

cidr6 :: V6HostAddress -> Word8 -> Maybe Cidr
cidr6 ha m = do
  na <- netAddress6 ha m
  let (ma, ra) = maskCidr6 ha m
  guard $ ma == ra
  return $ Cidr na
