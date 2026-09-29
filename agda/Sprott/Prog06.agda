{-# OPTIONS --safe #-}

module Sprott.Prog06 where

open import Agda.Builtin.Bool using (Bool; true; false)
open import Agda.Builtin.Char using (Char; primCharEquality; primNatToChar)
open import Agda.Builtin.Float using
  ( Float
  ; primFloatPlus
  ; primFloatMinus
  ; primFloatTimes
  ; primFloatDiv
  ; primFloatPow
  ; primFloatNegate
  ; primFloatSqrt
  ; primFloatLog
  ; primFloatLess
  ; primFloatEquality
  ; primNatToFloat
  ; primFloatRound
  ; primIntToFloat
  )
open import Agda.Builtin.Int using (Int)
open import Agda.Builtin.List using (List; []; _∷_)
open import Agda.Builtin.Maybe using (Maybe; just; nothing)
open import Agda.Builtin.Nat using
  ( Nat
  ; zero
  ; suc
  ; _+_
  ; _-_
  ; _*_
  ; _<_
  ; _==_
  ; div-helper
  ; mod-helper
  )

------------------------------------------------------------------------
-- Small builtin-only prelude
------------------------------------------------------------------------

record Pair (A B : Set) : Set where
  constructor pair
  field
    first  : A
    second : B

open Pair public

if_then_else_ : {A : Set} → Bool → A → A → A
if true  then yes else no = yes
if false then yes else no = no

not : Bool → Bool
not true  = false
not false = true

infixr 3 _∧ᵇ_
infixr 2 _∨ᵇ_

_∧ᵇ_ : Bool → Bool → Bool
true  ∧ᵇ b = b
false ∧ᵇ b = false

_∨ᵇ_ : Bool → Bool → Bool
true  ∨ᵇ b = true
false ∨ᵇ b = b

infixr 5 _++_

_++_ : {A : Set} → List A → List A → List A
[]       ++ ys = ys
(x ∷ xs) ++ ys = x ∷ (xs ++ ys)

map_list : {A B : Set} → (A → B) → List A → List B
map_list f [] = []
map_list f (x ∷ xs) = f x ∷ map_list f xs

repeat : {A : Set} → Nat → A → List A
repeat zero    x = []
repeat (suc n) x = x ∷ repeat n x

nth : {A : Set} → A → Nat → List A → A
nth fallback zero    []       = fallback
nth fallback zero    (x ∷ xs) = x
nth fallback (suc n) []       = fallback
nth fallback (suc n) (x ∷ xs) = nth fallback n xs

replace : {A : Set} → Nat → A → List A → List A
replace zero    y []       = y ∷ []
replace zero    y (x ∷ xs) = y ∷ xs
replace (suc n) y []       = []
replace (suc n) y (x ∷ xs) = x ∷ replace n y xs

infix 4 _≤ⁿ_ _>ⁿ_ _≥ⁿ_

_≤ⁿ_ : Nat → Nat → Bool
a ≤ⁿ b = not (b < a)

_>ⁿ_ : Nat → Nat → Bool
a >ⁿ b = b < a

_≥ⁿ_ : Nat → Nat → Bool
a ≥ⁿ b = b ≤ⁿ a

infixl 6 _+ᶠ_ _-ᶠ_
infixl 7 _*ᶠ_ _/ᶠ_
infix 4 _<ᶠ_ _≤ᶠ_ _>ᶠ_ _≥ᶠ_ _==ᶠ_

_+ᶠ_ : Float → Float → Float
_+ᶠ_ = primFloatPlus

_-ᶠ_ : Float → Float → Float
_-ᶠ_ = primFloatMinus

_*ᶠ_ : Float → Float → Float
_*ᶠ_ = primFloatTimes

_/ᶠ_ : Float → Float → Float
_/ᶠ_ = primFloatDiv

_<ᶠ_ : Float → Float → Bool
_<ᶠ_ = primFloatLess

_==ᶠ_ : Float → Float → Bool
_==ᶠ_ = primFloatEquality

_≤ᶠ_ : Float → Float → Bool
a ≤ᶠ b = not (b <ᶠ a)

_>ᶠ_ : Float → Float → Bool
a >ᶠ b = b <ᶠ a

_≥ᶠ_ : Float → Float → Bool
a ≥ᶠ b = b ≤ᶠ a

negᶠ : Float → Float
negᶠ = primFloatNegate

absᶠ : Float → Float
absᶠ x = if x <ᶠ 0.0 then negᶠ x else x

minᶠ : Float → Float → Float
minᶠ a b = if a <ᶠ b then a else b

maxᶠ : Float → Float → Float
maxᶠ a b = if a <ᶠ b then b else a

------------------------------------------------------------------------
-- PROG06 constants
------------------------------------------------------------------------

history_size : Nat
history_size = 500

previous_iterate : Nat
previous_iterate = 5

max_iterations : Nat
max_iterations = 11000

dimension : Nat
dimension = 2

coefficient_count : Nat
coefficient_count = 12

------------------------------------------------------------------------
-- Portable replacement for BASIC RND, plus Sprott's 100-slot shuffle
------------------------------------------------------------------------

-- PROG06 delegates the primitive random stream to the BASIC runtime.  The
-- translation keeps the 100-slot shuffle exactly as a program concept, but
-- supplies a deterministic 16-bit LCG underneath it so this module has no
-- hidden runtime dependency.  Search behavior does not depend on reproducing
-- one particular historical BASIC implementation's RND bit stream.

mod_65536 : Nat → Nat
mod_65536 n = mod-helper 0 65535 n 65535

mod_500 : Nat → Nat
mod_500 n = mod-helper 0 499 n 499

div_65536 : Nat → Nat
div_65536 n = div-helper 0 65535 n 65535

scale_random : Nat → Nat → Nat
scale_random bound sample = div_65536 (bound * sample)

next_raw : Nat → Pair Nat Nat
next_raw seed =
  let next = mod_65536 (25173 * seed + 13849)
  in pair next next

fill_pool : Nat → Nat → Pair (List Nat) Nat
fill_pool zero seed = pair [] seed
fill_pool (suc n) seed =
  let draw = next_raw seed
      rest = fill_pool n (second draw)
  in pair (first draw ∷ first rest) (second rest)

record Rng : Set where
  constructor rng
  field
    rng_seed        : Nat
    shuffled_value  : Nat
    shuffle_pool    : List Nat
    shuffle_ready   : Bool

open Rng public

prepare_rng : Rng → Rng
prepare_rng r =
  let pool_zero = nth 0 0 (shuffle_pool r) == 0
      needs_fill = not (shuffle_ready r) ∨ᵇ pool_zero
  in if needs_fill
     then let filled = fill_pool 100 (rng_seed r)
          in rng (second filled) 0 (first filled) true
     else r

shuffle_draw : Rng → Pair Nat Rng
shuffle_draw r =
  let ready       = prepare_rng r
      slot        = scale_random 100 (shuffled_value ready)
      sampled     = nth 0 slot (shuffle_pool ready)
      replacement = next_raw (rng_seed ready)
      pool₂       = replace slot (first replacement) (shuffle_pool ready)
      rng₂        = rng (second replacement) sampled pool₂ true
  in pair sampled rng₂

coefficient_from_digit : Nat → Float
coefficient_from_digit digit with digit < 12
... | true  = negᶠ (primNatToFloat (12 - digit) /ᶠ 10.0)
... | false = primNatToFloat (digit - 12) /ᶠ 10.0

record CoefficientDraw : Set where
  constructor coefficient_draw
  field
    drawn_coefficients : List Float
    drawn_digits       : List Nat
    rng_after_draw     : Rng

open CoefficientDraw public

draw_coefficients : Nat → Rng → CoefficientDraw
draw_coefficients zero r = coefficient_draw [] [] r
draw_coefficients (suc n) r =
  let draw  = shuffle_draw r
      digit = scale_random 25 (first draw)
      rest  = draw_coefficients n (second draw)
  in coefficient_draw
       (coefficient_from_digit digit ∷ drawn_coefficients rest)
       (digit ∷ drawn_digits rest)
       (rng_after_draw rest)

record Parameters : Set where
  constructor parameters
  field
    coefficients : List Float
    code_digits  : List Nat

open Parameters public

consume_raw : Rng → Rng
consume_raw r =
  let draw = next_raw (rng_seed r)
  in rng (second draw) (shuffled_value r) (shuffle_pool r) (shuffle_ready r)

new_parameters : Rng → Pair Parameters Rng
new_parameters r =
  -- The BASIC program consumes one primitive RND value while selecting the
  -- polynomial order.  With OMAX = 2 the order remains 2, but the draw still
  -- advances the primitive stream.
  let r₁   = consume_raw r
      draw = draw_coefficients coefficient_count r₁
  in pair
       (parameters (drawn_coefficients draw) (drawn_digits draw))
       (rng_after_draw draw)

digit_character : Nat → Char
digit_character d = primNatToChar (65 + d)

parameter_code : Parameters → List Char
parameter_code p = 'E' ∷ map_list digit_character (code_digits p)

coefficient : Parameters → Nat → Float
coefficient p i = nth 0.0 i (coefficients p)

------------------------------------------------------------------------
-- Dynamical system and search state
------------------------------------------------------------------------

record Point2 : Set where
  constructor point2
  field
    point_x : Float
    point_y : Float

open Point2 public

map_step : Parameters → Float → Float → Point2
map_step p x y =
  let a0  = coefficient p 0
      a1  = coefficient p 1
      a2  = coefficient p 2
      a3  = coefficient p 3
      a4  = coefficient p 4
      a5  = coefficient p 5
      a6  = coefficient p 6
      a7  = coefficient p 7
      a8  = coefficient p 8
      a9  = coefficient p 9
      a10 = coefficient p 10
      a11 = coefficient p 11
      x₂  = a0 +ᶠ x *ᶠ (a1 +ᶠ a2 *ᶠ x +ᶠ a3 *ᶠ y)
                +ᶠ y *ᶠ (a4 +ᶠ a5 *ᶠ y)
      y₂  = a6 +ᶠ x *ᶠ (a7 +ᶠ a8 *ᶠ x +ᶠ a9 *ᶠ y)
                +ᶠ y *ᶠ (a10 +ᶠ a11 *ᶠ y)
  in point2 x₂ y₂

record Bounds : Set where
  constructor bounds
  field
    x_min : Float
    x_max : Float
    y_min : Float
    y_max : Float

open Bounds public

record Viewport : Set where
  constructor viewport
  field
    view_left   : Float
    view_right  : Float
    view_bottom : Float
    view_top    : Float

open Viewport public

record Orbit : Set where
  constructor orbit
  field
    current_x : Float
    current_y : Float
    nearby_x  : Float
    nearby_y  : Float

open Orbit public

record Statistics : Set where
  constructor statistics
  field
    iteration_count : Nat
    lyapunov_count  : Nat
    lyapunov_sum    : Float
    lyapunov_value  : Float
    observed_bounds : Bounds
    current_view    : Viewport
    x_history       : List Float
    history_index   : Nat

open Statistics public

record Machine : Set where
  constructor machine
  field
    active_parameters : Parameters
    random_state      : Rng
    orbit_state       : Orbit
    stats             : Statistics
    sound_enabled     : Bool

open Machine public

initial_bounds : Bounds
initial_bounds = bounds 1000000.0 -1000000.0 1000000.0 -1000000.0

initial_viewport : Viewport
initial_viewport = viewport -0.1 1.1 -0.1 1.1

new_search : Rng → Bool → Machine
new_search r sound =
  let p = new_parameters r
  in machine
       (first p)
       (second p)
       (orbit 0.05 0.05 0.050001 0.05)
       (statistics
         0
         0
         0.0
         0.0
         initial_bounds
         initial_viewport
         (repeat history_size 0.0)
         0)
       sound

initial_machine : Nat → Machine
initial_machine seed = new_search (rng (mod_65536 seed) 0 [] false) false

------------------------------------------------------------------------
-- Rendering and sound are explicit events instead of DOS side effects.
------------------------------------------------------------------------

data Event : Set where
  set_graphics_mode : Nat → Event
  clear_screen      : Event
  searching         : Event
  set_viewport      : Viewport → Event
  draw_border       : Viewport → Event
  plot_point        : Float → Float → Event
  play_tone         : Float → Nat → Event
  stopped           : Event

boot_events : List Event
boot_events =
  set_graphics_mode 12 ∷
  set_viewport initial_viewport ∷
  clear_screen ∷
  searching ∷
  []

update_observed_bounds : Nat → Float → Float → Bounds → Bounds
update_observed_bounds n x y b =
  if (100 ≤ⁿ n) ∧ᵇ (n ≤ⁿ 1000)
  then bounds
         (minᶠ x (x_min b))
         (maxᶠ x (x_max b))
         (minᶠ y (y_min b))
         (maxᶠ y (y_max b))
  else b

widen_if_tiny : Float → Float → Pair Float Float
widen_if_tiny low high =
  if (high -ᶠ low) <ᶠ 0.000001
  then pair (low -ᶠ 0.0000005) (high +ᶠ 0.0000005)
  else pair low high

viewport_from_bounds : Bounds → Viewport
viewport_from_bounds b =
  let ylow0  = if dimension == 1 then x_min b else y_min b
      yhigh0 = if dimension == 1 then x_max b else y_max b
      xr     = widen_if_tiny (x_min b) (x_max b)
      yr     = widen_if_tiny ylow0 yhigh0
      mx     = 0.1 *ᶠ (second xr -ᶠ first xr)
      my     = 0.1 *ᶠ (second yr -ᶠ first yr)
  in viewport
       (first xr -ᶠ mx)
       (second xr +ᶠ mx)
       (first yr -ᶠ my)
       (second yr +ᶠ my)

inside_view : Float → Float → Viewport → Bool
inside_view x y v =
  (x >ᶠ view_left v)
  ∧ᵇ (x <ᶠ view_right v)
  ∧ᵇ (y >ᶠ view_bottom v)
  ∧ᵇ (y <ᶠ view_top v)

rounded_float : Maybe Int → Float
rounded_float nothing  = 0.0
rounded_float (just i) = primIntToFloat i

sound_frequency : Float → Viewport → Float
sound_frequency new_x v =
  let normalized = (new_x -ᶠ view_left v) /ᶠ (view_right v -ᶠ view_left v)
      semitones  = rounded_float (primFloatRound (36.0 *ᶠ normalized))
  in 220.0 *ᶠ primFloatPow 2.0 (semitones /ᶠ 12.0)

record DisplayResult : Set where
  constructor display_result
  field
    display_statistics : Statistics
    display_events     : List Event

open DisplayResult public

display_step : Machine → Nat → Point2 → DisplayResult
display_step m next_count next_point =
  let s            = stats m
      o            = orbit_state m
      b₁           = update_observed_bounds next_count (current_x o) (current_y o) (observed_bounds s)
      resize_now   = next_count == 1000
      v₁           = if resize_now then viewport_from_bounds b₁ else current_view s
      history₁     = replace (history_index s) (current_x o) (x_history s)
      next_index   = mod_500 (history_index s + 1)
      previous_at  = mod_500 (next_index + history_size - previous_iterate)
      plot_x       = if dimension == 1 then nth 0.0 previous_at history₁ else current_x o
      plot_y       = if dimension == 1 then point_x next_point else current_y o
      can_plot     = (next_count ≥ⁿ 1000) ∧ᵇ inside_view plot_x plot_y v₁
      resize_events =
        if resize_now
        then clear_screen ∷ set_viewport v₁ ∷ draw_border v₁ ∷ []
        else []
      plot_events =
        if can_plot
        then if sound_enabled m
             then plot_point plot_x plot_y ∷ play_tone (sound_frequency (point_x next_point) v₁) 1 ∷ []
             else plot_point plot_x plot_y ∷ []
        else []
      s₁ = statistics
             next_count
             (lyapunov_count s)
             (lyapunov_sum s)
             (lyapunov_value s)
             b₁
             v₁
             history₁
             next_index
  in display_result s₁ (resize_events ++ plot_events)

------------------------------------------------------------------------
-- Lyapunov estimate and stopping tests
------------------------------------------------------------------------

record LyapunovResult : Set where
  constructor lyapunov_result
  field
    next_nearby_x       : Float
    next_nearby_y       : Float
    next_lyapunov_sum   : Float
    next_lyapunov_count : Nat
    next_lyapunov_value : Float

open LyapunovResult public

lyapunov_nonzero : Machine → Point2 → Statistics → Float → Float → Float → LyapunovResult

lyapunov_step : Machine → Point2 → Statistics → LyapunovResult
lyapunov_step m primary displayed =
  let o       = orbit_state m
      nearby  = map_step (active_parameters m) (nearby_x o) (nearby_y o)
      dx      = point_x nearby -ᶠ point_x primary
      dy      = point_y nearby -ᶠ point_y primary
      distance_squared = dx *ᶠ dx +ᶠ dy *ᶠ dy
  in lyapunov_nonzero m primary displayed dx dy distance_squared

lyapunov_nonzero m primary displayed dx dy distance_squared =
  if distance_squared ≤ᶠ 0.0
  then lyapunov_result
         (nearby_x (orbit_state m))
         (nearby_y (orbit_state m))
         (lyapunov_sum displayed)
         (lyapunov_count displayed)
         (lyapunov_value displayed)
  else
    let df     = 1.0e12 *ᶠ distance_squared
        scale  = 1.0 /ᶠ primFloatSqrt df
        near_x = point_x primary +ᶠ scale *ᶠ dx
        near_y = point_y primary +ᶠ scale *ᶠ dy
        sum₂   = lyapunov_sum displayed +ᶠ primFloatLog df
        count₂ = suc (lyapunov_count displayed)
        value₂ = 0.721347 *ᶠ sum₂ /ᶠ primNatToFloat count₂
    in lyapunov_result near_x near_y sum₂ count₂ value₂

------------------------------------------------------------------------
-- Main state machine
------------------------------------------------------------------------

data Command : Set where
  no_command   : Command
  toggle_sound : Command
  quit         : Command

command_from_key : Maybe Char → Command
command_from_key nothing = no_command
command_from_key (just c) =
  if primCharEquality c 'S' ∨ᵇ primCharEquality c 's'
  then toggle_sound
  else quit

data Decision : Set where
  continue : Decision
  restart  : Decision
  halt     : Decision

flip : Bool → Bool
flip true  = false
flip false = true

base_decision : Machine → Nat → Point2 → LyapunovResult → Decision
base_decision m next_count p lyap =
  let o = orbit_state m
      unbounded = (absᶠ (point_x p) +ᶠ absᶠ (point_y p)) >ᶠ 1000000.0
      finished  = next_count ≥ⁿ max_iterations
      fixed     = (absᶠ (point_x p -ᶠ current_x o) +ᶠ absᶠ (point_y p -ᶠ current_y o)) <ᶠ 0.000001
      cycle     = (next_count >ⁿ 100) ∧ᵇ (next_lyapunov_value lyap <ᶠ 0.005)
  in if unbounded ∨ᵇ finished ∨ᵇ fixed ∨ᵇ cycle then restart else continue

command_decision : Command → Decision → Decision
command_decision no_command   d = d
command_decision toggle_sound d = continue
command_decision quit         d = halt

command_sound : Command → Bool → Bool
command_sound toggle_sound sound = flip sound
command_sound no_command   sound = sound
command_sound quit         sound = sound

record StepResult : Set where
  constructor step_result
  field
    next_machine : Machine
    events       : List Event
    decision     : Decision

open StepResult public

finish_step : Decision → Machine → List Event → StepResult

step : Command → Machine → StepResult
step command m =
  let o            = orbit_state m
      primary      = map_step (active_parameters m) (current_x o) (current_y o)
      next_count   = suc (iteration_count (stats m))
      shown        = display_step m next_count primary
      shown_stats  = display_statistics shown
      lyap         = lyapunov_step m primary shown_stats
      completed_stats = statistics
        next_count
        (next_lyapunov_count lyap)
        (next_lyapunov_sum lyap)
        (next_lyapunov_value lyap)
        (observed_bounds shown_stats)
        (current_view shown_stats)
        (x_history shown_stats)
        (history_index shown_stats)
      advanced_orbit = orbit
        (point_x primary)
        (point_y primary)
        (next_nearby_x lyap)
        (next_nearby_y lyap)
      toggled_sound = command_sound command (sound_enabled m)
      advanced = machine
        (active_parameters m)
        (random_state m)
        advanced_orbit
        completed_stats
        toggled_sound
      decided = command_decision command (base_decision m next_count primary lyap)
  in finish_step decided advanced (display_events shown)

finish_step continue m es = step_result m es continue
finish_step restart  m es = step_result (new_search (random_state m) (sound_enabled m)) es restart
finish_step halt     m es = step_result m (es ++ (stopped ∷ [])) halt

------------------------------------------------------------------------
-- Finite driver for tests, notebooks, and host integrations.
------------------------------------------------------------------------

run_steps : Nat → Machine → Machine
run_steps zero    m = m
run_steps (suc n) m with step no_command m
... | step_result next es continue = run_steps n next
... | step_result next es restart  = run_steps n next
... | step_result next es halt     = next
