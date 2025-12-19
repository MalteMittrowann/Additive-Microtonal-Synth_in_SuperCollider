s.boot;

s.stop;

ServerOptions.devices;

(
o = Server.default.options;
o.inDevice  = nil;     // kein Input
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

	// ADSR settings
	~att = 0.01;  // Attack in sec
	~dec = 0.3;   // Decay in sec
	~sus = 0.6;   // Sustain as a ratio (0.0-1.0)
	~rel = 1.5;   // Release in sec

	// Array for Synth management
	~activeSynths = Array.newClear(128);

	//****************************
	// --- 2. SYNTH DEFINITION ---
	//****************************

	SynthDef(\additiveMicro, {
		arg note = 69, amp = 0.2, gate = 1, out = 0,
		f0 = 440, octaveRatio = 2.0, stepsPerOctave = 12,
		bright = 1.5, detune = 0.002, inharm = 0.0001,
		att = 0.01, dec = 0.3, sus = 0.5, rel = 1.0;

		var sig, env, partials, freqs, amps, phases, midiNote, calculatedFreq;

		calculatedFreq = f0 * (octaveRatio.pow((note - 69) / stepsPerOctave));

		partials = [1..12];
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

		Out.ar(out, Pan2.ar(sig * env * amp, 0));
	}).add;

	s.sync; // Wait for the SynthDef to be loaded

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
					\amp, ~amp
					\detune, ~detune,
					\inharm, ~inharm,
					// ADSR-Settings:
					\att, ~att, \dec, ~dec, \sus, ~sus, \rel, ~rel
				);
			}
		});
		"UPDATE variables: -> F0:% | OctaveRatio:% | StepsPerOctave:% | Inharm:% | Detune:% | Amplification:% | ADSR: % % % %".format(
			~f0, ~octRatio, ~steps, ~inharm, ~detune, ~amp, ~att, ~dec, ~sus, ~rel).postln;
	};

	//******************************
	// --- 4. MIDI CONFIGURATION ---
	//******************************

	MIDIClient.init;
	MIDIIn.connectAll;

	// Note On
	MIDIdef.noteOn(\on, { |vel, num|
		~activeSynths[num] = Synth(\additiveOrganic, [
			\note, num,
			\bright, vel.linlin(0, 127, 3.5, 0.6),
			\amp, vel.linlin(0, 127, 0, ~amp),
			\detune, ~detune,
			\inharm, ~inharm,
			\f0, ~f0,
			\octaveRatio, ~octRatio,
			\stepsPerOctave, ~steps,
			// ADSR-Settings:
			\att, ~att, \dec, ~dec, \sus, ~sus, \rel, ~rel
		]).onFree({ ~activeSynths[num] = nil });
	});

	// Note Off
	MIDIdef.noteOff(\off, { |vel, num|
		~activeSynths[num].set(\gate, 0);
	});

	"SYNTHESIZER ACTIVE!".postln;
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
~octRatio = 2.1; ~updateSynths.value;
~octRatio = 2.0; ~updateSynths.value;

// Equal tempered steps in one octave
~steps = 5; ~updateSynths.value;
~steps = 12; ~updateSynths.value;
~steps = 19; ~updateSynths.value;

// Concert pitch in Hz
~f0 = 432; ~updateSynths.value;
~f0 = 440; ~updateSynths.value;

// Main-Velocity
~amp = 0.4; ~updateSynths.value;

// Sound quality
~detune = 0.005; ~updateSynths.value;
~inharm = 0.0002; ~updateSynths.value;

// ADSR-Settings

~att = 0.05; ~dec = 0.0; ~sus = 1.0; ~rel = 0.1; ~updateSynths.value; // Organ
~att = 0.01; ~dec = 2.0; ~sus = 0.2; ~rel = 0.8; ~updateSynths.value; // Piano
~att = 2.0; ~dec = 0.5; ~sus = 0.8; ~rel = 3.0; ~updateSynths.value; // Strings

s.freeAll;