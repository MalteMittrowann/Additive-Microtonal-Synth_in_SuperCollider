s.boot;

s.stop;

ServerOptions.devices;

(
o = Server.default.options;
o.inDevice  = nil;     // kein Input
o.outDevice = "Windows WASAPI : Lautsprecher (Jabra Evolve2 30 SE)";
o.numOutputBusChannels = 2;
o.numInputBusChannels = 0;
)

s.reboot;

/* KOMPLETTES SKRIPT: Additive Synthese mit dynamischer Skalierung
   Anleitung:
   1. Alles markieren und einmal ausführen (Strg + Enter).
   2. Die Steuerzeilen ganz unten einzeln nutzen, um den Sound live zu verändern.
*/

(
s.waitForBoot({

	// --- 1. GLOBALE VARIABLEN INITIALISIEREN ---
	~f0 = 440;            // Kammerton
	~octRatio = 2.0;      // Frequenzverhältnis der "Oktave"
	~steps = 12;          // Stufen pro Oktave
	~amp = 0.2;           // Gesamtlautstärke
	~activeSynths = Array.newClear(128); // Container für Noten-Management

	// --- 2. SYNTH DEFINITION ---
	SynthDef(\additiveMicro, {
		arg note = 69, amp = 0.2, gate = 1, out = 0,
		f0 = 440, octaveRatio = 2.0, stepsPerOctave = 12,
		att = 0.05, rel = 0.8,
		bright = 1.0; // Neue Variable für die Helligkeit (aus Velocity)

		var sig, env, partials, freqs, amps, phases, midiNote, calculatedFreq;

		calculatedFreq = f0 * (octaveRatio.pow((note - 69) / stepsPerOctave));

		partials = [1, 2, 3, 4, 5, 6, 7, 8];
		freqs = partials * calculatedFreq;

		// Dynamische Berechnung der Amplituden basierend auf 'bright'
		// Je höher 'bright', desto lauter die höheren Partials
		amps = partials.collect({ |i|
			1 / (i.pow(bright))
		});

		// Normalisierung, damit es nicht zu laut wird bei vielen Obertönen
		amps = amps / amps.sum;

		phases = Array.fill(8, 0);

		sig = Klang.ar(`[freqs, amps, phases]);
		env = EnvGen.kr(Env.asr(att, 1, rel), gate, doneAction: 2);

		Out.ar(out, Pan2.ar(sig * env * amp, 0));
	}).add;

	s.sync; // Warten, bis SynthDef geladen ist

	// --- 3. HILFSFUNKTION FÜR LIVE-UPDATES ---
	~updateSynths = {
		~activeSynths.do({ |synth|
			if(synth.notNil && synth.isPlaying) {
				synth.set(
					\f0, ~f0,
					\octaveRatio, ~octRatio,
					\stepsPerOctave, ~steps,
					\amp, ~amp
				);
			}
		});
		"LOG -> f0:% | Ratio:% | Steps:%".format(~f0, ~octRatio, ~steps).postln;
	};

	// --- 4. MIDI KONFIGURATION ---
	MIDIClient.init;
	MIDIIn.connectAll;

	// Note On
	MIDIdef.noteOn(\on, { |vel, num|
		var brightness = vel.linlin(0, 127, 3.0, 0.5); // 0=dumpf(3.0), 127=hell(0.5)

		~activeSynths[num] = Synth(\additiveMicro, [
			\note, num,
			\amp, vel.linlin(0, 127, 0, ~amp), // Lautstärke weiterhin über Velocity
			\bright, brightness,               // Obertonstruktur über Velocity
			\f0, ~f0,
			\octaveRatio, ~octRatio,
			\stepsPerOctave, ~steps
		]).onFree({ ~activeSynths[num] = nil });
	});

	// Note Off
	MIDIdef.noteOff(\off, { |vel, num|
		~activeSynths[num].set(\gate, 0);
	});

	"SYNTHESIZER BEREIT!".postln;
});
)

(
// --- VIRTUELLES KEYBOARD MIT INDIVIDUELLER VELOCITY ---
var window, keyMap;

// Mapping: Taste -> [MIDI-Note, Velocity]
// Hier kannst du die Velocity-Werte (0-127) für jede Taste einzeln hardcoden
keyMap = (
	$y: [60, 30],  // C  - sehr leise/dumpf
	$z: [60, 30],  // C  - (für US-Layout)
	$s: [61, 45],  // C#
	$x: [62, 60],  // D  - moderat
	$d: [63, 75],  // D#
	$c: [64, 90],  // E  - hell
	$v: [65, 110], // F  - sehr hell
	$g: [66, 127], // F# - maximale Brillanz
	$b: [67, 80],  // G
	$h: [68, 80],  // G#
	$n: [69, 80],  // A
	$j: [70, 80],  // A#
	$m: [71, 80],  // B
	$,: [72, 80]   // C2
);

window = Window("Keyboard Velocity Test", Rect(200, 200, 400, 100)).front;

window.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
	var data = keyMap[char];
	if (data.notNil) {
		var note = data[0];
		var vel  = data[1];
		// Ruft deinen MIDIdef mit der individuellen Velocity auf
		MIDIdef.noteOn(\on).func.value(vel, note);
	};
};

window.view.keyUpAction = { |view, char, modifiers, unicode, keycode|
	var data = keyMap[char];
	if (data.notNil) {
		var note = data[0];
		// Note Off sendet üblicherweise Velocity 0
		MIDIdef.noteOff(\off).func.value(0, note);
	};
};

"Individuelles Keyboard aktiv. Teste 'y' (leise) vs 'g' (laut/hell)!".postln;
)

/* --- INTERAKTIVE STEUERUNG (Live-Coding Bereich) ---
   Bewege den Cursor in eine Zeile und drücke Strg + Enter
*/

~octRatio = 2.1; ~updateSynths.value;  // Leichte Streckung (glockig/unharmonisch)
~octRatio = 2.0; ~updateSynths.value;  // Zurück zu reinem 12-TET

~steps = 5; ~updateSynths.value;       // Pentatonische Verteilung über die Oktave
~steps = 19; ~updateSynths.value;      // 19-stufige Skala

~f0 = 432; ~updateSynths.value;        // Grundstimmung ändern
~f0 = 440; ~updateSynths.value;

~amp = 0.4; ~updateSynths.value;       // Gesamtlautstärke ändern

// Alles stoppen, falls nötig
s.freeAll;