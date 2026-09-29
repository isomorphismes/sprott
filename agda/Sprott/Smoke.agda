{-# OPTIONS --safe #-}

module Sprott.Smoke where

open import Agda.Builtin.Bool using (Bool)
open import Agda.Builtin.Nat using (Nat)
open import Sprott.Prog06

-- Type-level smoke surface. Keeping these values named makes accidental
-- interface breakage visible when the module is typechecked.

seed : Nat
seed = 1

machine₀ : Machine
machine₀ = initial_machine seed

machine₁ : Machine
machine₁ = next_machine (step no_command machine₀)

sound₁ : Bool
sound₁ = sound_enabled (next_machine (step toggle_sound machine₀))

machine₁₀₀ : Machine
machine₁₀₀ = run_steps 100 machine₀
