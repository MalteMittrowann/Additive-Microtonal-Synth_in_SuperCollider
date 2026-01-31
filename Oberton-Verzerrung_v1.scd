s.boot;

s.stop;

ServerOptions.devices;

(
o = Server.default.options;
o.inDevice  = nil;
o.outDevice = "Windows WASAPI : Kopfhoerer (Realtek(R) Audio)";
o.numOutputBusChannels = 2;
o.numInputBusChannels = 0;
)

s.reboot;

(
s.waitForBoot({

	//***************************************
	// --- 1. INITIALISE GLOBAL VARIABLES ---
	//***************************************

	// Calculation of pitches
	~f0 = 440;            // Concert Pitch
	~octRatio = 2.0;      // Frequency relation of the octave
	~steps = 12;          // Equal tempered steps in one octave

	// Sound settings
	~amp = 0.2;           // Main velociy
	~detune = 0.002;      // Random drift
	~inharm = 0.0001;     // Inharmonizität (Saitensteifigkeit)

	// String simulation
	~stringSim = 1;       // 0 = no string simulation --> note is sustained for as long the key is held, 1 = string simulation --> in the sustain phase the note fades out
	~fadeOutTime = 3.0;   // Fade-out time

	// ADSR settings
	~att = 0.01;  // Attack in sec
	~dec = 0.3;   // Decay in sec
	~sus = 0.6;   // Sustain as a ratio (0.0-1.0)
	~rel = 1.5;   // Release in sec

	// Array for Synth management
	~activeSynths = Array.newClear(128);

	~pedalDown = false;           // Sustain pedal
	~sustainedNotes = Set.new;    // Set of notes held by the sustain pedal

	//****************************
	// --- 2. SYNTH DEFINITION ---
	//****************************

	SynthDef(\additiveSynth, {
		arg note = 69, amp = 0.2, gate = 1, out = 0,
		f0 = 440, octaveRatio = 2.0, stepsPerOctave = 12,
		bright = 1.5, detune = 0.002, inharm = 0.0001,
		att = 0.01, dec = 0.3, sus = 0.5, rel = 1.0, stringSim = 1, fadeOutTime = 4.0;

		var sig, env, partials, freqs, amps, phases, midiNote, calculatedFreq, stringDamp;

		calculatedFreq = f0 * (octaveRatio.pow((note - 69) / stepsPerOctave));

		partials = (1..30);
		freqs = partials.collect({ |i|
			var base = calculatedFreq * i;
			// Physik: Saitensteifigkeit
			var stretching = (1 + (inharm * i.pow(2))).sqrt;
			// Chaos: Leichter Pitch-Drift pro Oberton
			var drift = LFNoise1.kr(Rand(0.2, 0.8)).range(1 - detune, 1 + detune);
			base * stretching * drift;
		});

		amps = partials.collect({ |i|
			1 / (i.pow(bright))
		});

		amps = amps / amps.sum;

		phases = Array.fill(12, { Rand(0, 2pi) }); //Random phases for the partials

		sig = Klang.ar(`[freqs, amps, phases]);
		env = EnvGen.kr(Env.adsr(att, dec, sus, rel), gate, doneAction: 2);

		stringDamp = Select.kr(stringSim, [
			DC.kr(1),
			XLine.kr(1.0, 0.001, fadeOutTime)
		]);

		Out.ar(out, Pan2.ar(sig * env * stringDamp * amp, 0));
	}).add;

	s.sync; // Wait for the SynthDef to be loaded

	"SYNTHESIZER ACTIVE!".postln;

	//********************************************************
	// --- 3. Helper Function for LIVE UPDATE OF VARIABLES ---
	//********************************************************

	~updateSynths = {
		~activeSynths.do({ |synth|
			if(synth.notNil && synth.isPlaying) {
				synth.set(
					\f0, ~f0,
					\octaveRatio, ~octRatio,
					\stepsPerOctave, ~steps,
					\amp, ~amp,
					\detune, ~detune,
					\inharm, ~inharm,
					\stringSim, ~stringSim,
					\fadeOutTime, ~fadeOutTime,
					// ADSR-Settings:
					\att, ~att, \dec, ~dec, \sus, ~sus, \rel, ~rel
				);
			}
		});
		"UPDATE variables: -> F0:% | OctaveRatio:% | StepsPerOctave:% | Inharm:% | Detune:% | Amplification:% | String-Simulation:% - FadeOutTime:% | ADSR: % % % %".format(
			~f0, ~octRatio, ~steps, ~inharm, ~detune, ~amp, ~stringSim, ~fadeOutTime, ~att, ~dec, ~sus, ~rel).postln;
	};

	//******************************
	// --- 4. MIDI CONFIGURATION ---
	//******************************

	MIDIClient.init;
	MIDIIn.connectAll;

	// -------------
	// Sustain pedal
	// -------------
	MIDIdef.cc(\sustainPedal, { |val|
		if (val >= 64) {
			// Sustain pedal is being pressed
			~pedalDown = true;
			"Pedal Down".postln;
		} {
			// Sustain pedal is being released
			~pedalDown = false;
			~sustainedNotes.do({ |noteNum|
				if (~activeSynths[noteNum].notNil) {
					~activeSynths[noteNum].set(\gate, 0);
					~activeSynths[noteNum] = nil;
				};
			});
			~sustainedNotes.clear;
			"Pedal Up -> Release Notes".postln;
		};
	}, 64);

	// -------
	// NOTE ON
	// -------
	MIDIdef.noteOn(\on, { |vel, num|
		if (vel > 0) {
			// Re-trigger note being played again with held pedal
			if (~sustainedNotes.includes(num)) {
				~sustainedNotes.remove(num);
			};
			if (~activeSynths[num].notNil) {
				~activeSynths[num].set(\gate, 0);
			};

			~activeSynths[num] = Synth(\additiveSynth, [
				\note, num,
				\velAmp, vel.linlin(0, 127, 0, ~amp),
				\bright, vel.linlin(0, 127, 3.5, 0.5),
				\f0, ~f0, \octaveRatio, ~octRatio, \stepsPerOctave, ~steps,
				\detune, ~detune, \inharm, ~inharm,
				\att, ~att, \dec, ~dec, \sus, ~sus, \rel, ~rel,
				\stringSim, ~stringSim, \fadeOutTime, ~fadeOutTime
			]);
		} {
			// Note on with velocity = 0 --> trigger noteOff
			MIDIdef.noteOff(\off).func.value(0, num);
		};
	});

	// --------
	// NOTE OFF
	// --------
	MIDIdef.noteOff(\off, { |vel, num|
		// Check: Is sustain pedal being pressed
		if (~pedalDown) {
			if (~activeSynths[num].notNil) {
				~sustainedNotes.add(num);
			};
		} {
			if (~activeSynths[num].notNil) {
				~activeSynths[num].set(\gate, 0);
				~activeSynths[num] = nil;
			};
		};
	});

	"MIDI-Config ACTIVE!".postln;

	// =================================================================
	// 5. HARDWARE CONTROLLER MAPPING (KORG nanoKONTROL2)
	// =================================================================

	// FADER 1: Grundfrequenz (300Hz bis 600Hz)
	MIDIdef.cc(\korg_f0, { |val|
		~f0 = val.linlin(0, 127, 300, 600);
		~updateSynths.value;
		"f0 = %".format(~f0).postln;
	}, 0); // CC Nummer 0

	// FADER 2: Oktaverhältnis (1.8 bis 2.2)
	MIDIdef.cc(\korg_ratio, { |val|
		~octRatio = val.linlin(0, 127, 1.8, 2.2);
		~updateSynths.value;
		"octRatio = %".format(~octRatio).postln;
	}, 1); // CC Nummer 1

	// FADER 3: Stufen pro Oktave (5 bis 24)
	MIDIdef.cc(\korg_steps, { |val|
		~steps = val.linlin(0, 127, 5, 24).round;
		~updateSynths.value;
		"steps = %".format(~steps).postln;
	}, 2); // CC Nummer 2

	// KNOB 1: Detune / Drift (0.0 bis 0.02)
	MIDIdef.cc(\korg_detune, { |val|
		~detune = val.linlin(0, 127, 0.0, 0.02);
		~updateSynths.value;
		"detune = %".format(~detune).postln;
	}, 16); // CC Nummer 16 (Standard für Knob 1 beim nanoKONTROL)

	// KNOB 2: Inharmonizität (0.0 bis 0.005)
	MIDIdef.cc(\korg_inharm, { |val|
		~inharm = val.linlin(0, 127, 0.0, 0.005);
		~updateSynths.value;
		"inharm = %".format(~inharm).postln;
	}, 17); // CC Nummer 17

	// FADER 8 (Master): Gesamtlautstärke
	MIDIdef.cc(\korg_amp, { |val|
		~amp = val.linlin(0, 127, 0.0, 0.5);
		~updateSynths.value;
		"amp = %".format(~amp).postln;
	}, 7); // CC Nummer 7

	// ADSR Steuerung (Slider 4, 5, 6, 7)
	MIDIdef.cc(\korg_att, { |val| ~att = val.linlin(0, 127, 0.01, 2.0); ~updateSynths.value; "ADSR: Attack = %".format(~att).postln;}, 3);
	MIDIdef.cc(\korg_dec, { |val| ~dec = val.linlin(0, 127, 0.01, 1.0); ~updateSynths.value; "ADSR: Decay = %".format(~dec).postln;}, 4);
	MIDIdef.cc(\korg_sus, { |val| ~sus = val.linlin(0, 127, 0.0, 1.0);  ~updateSynths.value; "ADSR: Sustain = %".format(~sus).postln;}, 5);
	MIDIdef.cc(\korg_rel, { |val| ~rel = val.linlin(0, 127, 0.1, 4.0);  ~updateSynths.value; "ADSR: Realease = %".format(~rel).postln;}, 6);


	// --- Debugging Tool ---
	// Check for naming of KORG nanoKontrol faders etc.
	MIDIdef.cc(\debugCC, { |val, num, chan|
		["CC received:", num, val].postln;
	});

	"Synth and Config ACTIVE!".postln;
});
)

(
// --- VIRTUAL KEYBOARD ---
var window, keyMap;

keyMap = (
	$y: [60, 30],
	$z: [60, 30],
	$s: [61, 45],
	$x: [62, 60],
	$d: [63, 75],
	$c: [64, 90],
	$v: [65, 110],
	$g: [66, 127],
	$b: [67, 20],
	$h: [68, 60],
	$n: [69, 100],
	$j: [70, 30],
	$m: [71, 70],
	$,: [72, 80]
);

window = Window("Keyboard Test with hardcoded Velocity values", Rect(200, 200, 400, 150)).front;

Button(window, Rect(10, 10, 380, 30))
	.states_([["STOP ALL NOTES", Color.white, Color.red]])
	.action_({
		(0..127).do({ |i|
			if(~activeSynths[i].notNil) { ~activeSynths[i].set(\gate, 0); };
			~activeSynths[i] = nil;
		});
		"Stopped all notes".postln;
		window.view.focus(true);
	});

StaticText(window, Rect(10, 50, 380, 20)).string_("Type: y, x, c, v... (This window needs to be active and in front!)");


window.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
	var data = keyMap[char.toLower];

	if (data.notNil) {
		var note = data[0];
		var vel = data[1];

		if (~activeSynths[note].isNil) {

			MIDIdef.noteOn(\on).func.value(vel, note);
			"Play Note: Data:%, Note:%, Velocity:%".format(data, note, vel).postln;

		} {
			"Ignore Repeat for Note:%".format(data).postln;
		};
	};
};

window.view.keyUpAction = { |view, char, modifiers, unicode, keycode|
	var data = keyMap[char.toLower];

	if (data.notNil) {
		var note = data[0];
		MIDIdef.noteOff(\off).func.value(0, note);
		"Release: Data:%, Note:%".format(data, note).postln;
	};
};

window.onClose = {
	(0..127).do({ |i|
		if(~activeSynths[i].notNil) { ~activeSynths[i].set(\gate, 0); }
	});
	"Close Keyboard".postln;
};
)

// Frequency-Relation of the octave
~octRatio = 1.75; ~updateSynths.value;
~octRatio = 2.5; ~updateSynths.value;
~octRatio = 2.0; ~updateSynths.value;

// Equal tempered steps in one octave
~steps = 5; ~updateSynths.value;
~steps = 12; ~updateSynths.value;
~steps = 19; ~updateSynths.value;

// Concert pitch in Hz
~f0 = 432; ~updateSynths.value;
~f0 = 440; ~updateSynths.value;

// Main-Velocity
~amp = 1.0; ~updateSynths.value;

// Sound quality
~detune = 0.005; ~updateSynths.value;
~inharm = 0.0002; ~updateSynths.value;

// String simulation
~stringSim = 0; ~updateSynths.value; // witout string simulation
~stringSim = 1; ~updateSynths.value; // with string simulation

~fadeOutTime = 0.8; ~updateSynths.value;
~fadeOutTime = 3.0; ~updateSynths.value;
~fadeOutTime = 8.0; ~updateSynths.value;

// ADSR-Settings

~att = 0.05; ~dec = 0.0; ~sus = 1.0; ~rel = 0.1; ~updateSynths.value; // Organ
~att = 0.01; ~dec = 2.0; ~sus = 0.2; ~rel = 0.8; ~updateSynths.value; // Piano
~att = 2.0; ~dec = 0.5; ~sus = 0.8; ~rel = 3.0; ~updateSynths.value; // Strings

s.freeAll;