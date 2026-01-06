# Additive-Microtonal-Synth_in_SuperCollider

**A SuperCollider project exploring dynamic microtonality and variable octave ratios through additive synthesis.**

## Audio Demos

Listen to the resulting sound experiments, featuring Ludwig van Beethoven's *Bagatelle Op. 33 No. 6*, interpreted through various spectral stretchings and compressions:

[**▶ Listen on SoundCloud: Spectral Beethoven Album**](https://soundcloud.com/malte-mittrowann-967083798/sets/spectral-beethoven-variable-octave-ratios-in-additive-synthesis)

---

## Project Overview

This project implements a custom real-time synthesis engine in **SuperCollider** designed to investigate the sonic implications of non-standard frequency ratios. By decoupling the harmonic series from the traditional 2:1 octave relationship, the synthesizer allows for the continuous "stretching" or "compressing" of the frequency spectrum.

The engine was used to re-interpret Beethoven's *Bagatelle Op. 33 No. 6 in D major*, demonstrating how structural changes in tuning directly affect the perceived timbre and emotional character of classical harmony.

### The Mathematical Concept
In Western 12-TET tuning, frequency is calculated as $f(i) = f_0 \cdot 2^{i/12}$. This project replaces the fixed octave (2) with a variable `ratio`:

$$f(i) = f_0 \cdot \text{ratio}^{\frac{i}{\text{steps}}}$$

* **ratio = 2.0:** Standard Octave (Harmonic).
* **ratio > 2.0:** Stretched Spectrum (Bell-like, metallic, "open" intervals).
* **ratio < 2.0:** Compressed Spectrum (Darker, denser, historically distinct).

## Key Features

### 1. Advanced Additive Engine
* **30-Partial Oscillator Bank:** Generates rich, complex timbres using the `Klang` UGen.
* **Velocity-to-Brightness Mapping:** Dynamic control over the spectral centroid based on MIDI velocity input ($Amplitude \propto 1/n^{brightness}$).

### 2. Physical Modeling Nuances
* **Inharmonicity Simulation:** Simulates the stiffness of physical strings by applying a non-linear frequency stretch to higher partials.
* **Bio-Drift:** Implements microscopic pitch fluctuation (`LFNoise1`) per partial to mimic organic instability and avoid digital sterility.
* **String Decay Logic:** Features a switchable "Piano Mode" where notes naturally fade out over time even when keys are held, contrasting with the infinite sustain of an "Organ Mode."

### 3. Full MIDI Integration
* **Polyphonic Control:** Handles note management, voice stealing, and re-triggering logic for responsive articulation.
* **Sustain Pedal Support:** Full implementation of CC 64 logic for realistic piano phrasing.
* **Real-time Parameter Control:** Mapped for hardware controllers (e.g., KORG nanoKONTROL2) to manipulate $f_0$, stretch ratio, and envelope settings on the fly.

## Usage & Installation

### Prerequisites
* [SuperCollider](https://supercollider.github.io/) (Version 3.10 or later recommended).

### How to Run
1.  Clone or download this repository.
2.  Open the `.scd` file in the SuperCollider IDE.
3.  Boot the Audio Server: Press `Ctrl + B` (Windows) or `Cmd + B` (Mac).
4.  Select the entire code block for the synth-definition and evaluate: Press `Ctrl + Enter` / `Cmd + Enter`.
5.  Connect a MIDI Keyboard to play.

It is also possible to play with the keyboard of your computer. For this activate the lower code-block named *virtual keyboard* and play with the keys y/z - m.
The velocity values are hardcoded for this testing of the script.

### Live Coding Variables
You can modify the sound in real-time by executing lines at the bottom of the script:

```supercollider
// Example: Stretch the octave to a ratio of 2.1
~octRatio = 2.1; ~updateSynths.value;

// Example: Switch to "Piano Mode" with a 4-second tail
~stringSim = 1; ~fadeOutTime = 4.0; ~updateSynths.value;
```
## Hardware Mapping

The script includes pre-configured mappings for standard MIDI controllers (e.g., KORG nanoKONTROL2, AKAI MPKmini):
* CC 0: Fundamental Frequency ($f_0$)
* CC 1: Octave Ratio (Stretch/Compress)
* CC 2: Steps per OctaveCC 64: Sustain Pedal
* CC 16/17: Detune & Inharmonicity
  
## License

This project is licensed under the MIT License - see the LICENSE file for details.
