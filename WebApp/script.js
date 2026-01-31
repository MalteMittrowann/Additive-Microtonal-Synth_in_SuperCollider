/**
 * Additive Microtonal Synthesizer with Elastic Spectras
 * Ported from SuperCollider
 * * Based on the formula: f(i) = f0 * ratio ^ ((note - 69) / steps)
 */

'use strict';

// --- 1. GLOBAL STATE & PARAMETERS ---
const params = {
    f0: 440,
    ratio: 2.0,
    steps: 12,
    inharm: 0.0001,
    bright: 1.5,
    att: 0.01, dec: 0.3, sus: 0.5, rel: 1.5
};

const activeNotes = {};
let isAudioStarted = false;
let analyser; 

// --- 2. AUDIO ENGINE (Tone.js) ---

class AdditiveVoice {
    constructor(noteNumber) {
        this.noteNumber = noteNumber;
        this.oscillators = [];
        
        this.envelope = new Tone.AmplitudeEnvelope({
            attack: params.att,
            decay: params.dec,
            sustain: params.sus,
            release: params.rel
        });

        this.envelope.connect(analyser);

        // f = f0 * ratio ^ ((note - 69) / steps)
        const noteIndex = noteNumber - 69; 
        const calculatedFreq = params.f0 * Math.pow(params.ratio, noteIndex / params.steps);

        // Generate 12 Partials
        for (let i = 1; i <= 12; i++) {
            const stretching = Math.sqrt(1 + (params.inharm * Math.pow(i, 2)));
            const freq = calculatedFreq * i * stretching;
            const amp = 1 / Math.pow(i, params.bright);
            
            const osc = new Tone.Oscillator(freq, "sine");
            osc.volume.value = Tone.gainToDb(amp * 0.08); 

            osc.connect(this.envelope);
            osc.start();
            this.oscillators.push(osc);
        }
    }

    triggerAttack() {
        this.envelope.triggerAttack();
    }

    triggerRelease() {
        this.envelope.release = params.rel;
        this.envelope.triggerRelease();
        
        const cleanupTime = (params.rel * 1000) + 1000;
        setTimeout(() => {
            this.oscillators.forEach(o => o.dispose());
            this.envelope.dispose();
        }, cleanupTime);
    }
}

// --- 3. UI HANDLING ---

function initAudio() {
    analyser = new Tone.Analyser("waveform", 1024);
    analyser.toDestination(); 

    Tone.start();
    isAudioStarted = true;
    
    document.getElementById('startBtn').style.display = 'none';
    document.getElementById('status').innerText = "Audio Engine Active. Play with Y-M.";
    
    startVisualizer();
}

function bindSlider(id, paramKey) {
    const slider = document.getElementById(id);
    const display = document.getElementById('val_' + id);
    
    slider.addEventListener('input', (e) => {
        const val = parseFloat(e.target.value);
        params[paramKey] = val;
        display.innerText = val;
    });
}

// --- 4. VISUALIZER ---
function startVisualizer() {
    const canvas = document.getElementById('oscilloscope');
    const ctx = canvas.getContext('2d');
    
    canvas.width = canvas.offsetWidth;
    canvas.height = canvas.offsetHeight;

    function draw() {
        requestAnimationFrame(draw);
        ctx.fillStyle = "#000";
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        const values = analyser.getValue();
        ctx.lineWidth = 2;
        ctx.strokeStyle = "#4CAF50"; 
        ctx.beginPath();

        const sliceWidth = canvas.width / values.length;
        let x = 0;

        for (let i = 0; i < values.length; i++) {
            const v = values[i] * 2; 
            const y = (v * canvas.height / 2) + (canvas.height / 2);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
            x += sliceWidth;
        }
        ctx.stroke();
    }
    draw();
}

// --- 5. KEYBOARD INPUT & VISUALS ---
const keyMap = {
    'y': 60, 'z': 60, 
    's': 61, 'x': 62, 'd': 63, 'c': 64, 'v': 65,
    'g': 66, 'b': 67, 'h': 68, 'n': 69, 'j': 70,
    'm': 71, ',': 72
};

// Helper: Visual Key Feedback
function toggleKeyVisual(keyChar, isActive) {
    // Finde das Element mit dem passenden data-key Attribut
    const keyElement = document.querySelector(`.key[data-key="${keyChar}"]`);
    if (keyElement) {
        if (isActive) keyElement.classList.add('active-visual');
        else keyElement.classList.remove('active-visual');
    }
}

window.addEventListener('keydown', (e) => {
    if (!isAudioStarted || e.repeat) return;
    
    const char = e.key.toLowerCase();
    const noteNum = keyMap[char];

    if (noteNum !== undefined && !activeNotes[char]) {
        // Audio
        const voice = new AdditiveVoice(noteNum);
        voice.triggerAttack();
        activeNotes[char] = voice;
        
        // Visual
        toggleKeyVisual(char, true);
        document.getElementById('status').innerHTML = `Playing Note: <b>${noteNum}</b>`;
    }
});

window.addEventListener('keyup', (e) => {
    const char = e.key.toLowerCase();
    
    // Audio Release
    if (activeNotes[char]) {
        activeNotes[char].triggerRelease();
        delete activeNotes[char];
        
        // Visual Release
        toggleKeyVisual(char, false);
        
        if (Object.keys(activeNotes).length === 0) {
             document.getElementById('status').innerText = "Ready.";
        }
    }
});

// Initialization
bindSlider('f0', 'f0');
bindSlider('ratio', 'ratio');
bindSlider('steps', 'steps');
bindSlider('inharm', 'inharm');
bindSlider('bright', 'bright');
bindSlider('rel', 'rel');

document.getElementById('startBtn').addEventListener('click', initAudio);

// Optional: Klickbarkeit der Tasten (Maus-Support)
document.querySelectorAll('.key').forEach(key => {
    key.addEventListener('mousedown', () => {
        if (!isAudioStarted) return;
        const note = parseInt(key.dataset.note);
        const char = key.dataset.key;
        
        // Simulate Keydown
        const voice = new AdditiveVoice(note);
        voice.triggerAttack();
        activeNotes[char] = voice;
        toggleKeyVisual(char, true);
    });

    key.addEventListener('mouseup', () => {
        if (!isAudioStarted) return;
        const char = key.dataset.key;
        if (activeNotes[char]) {
            activeNotes[char].triggerRelease();
            delete activeNotes[char];
            toggleKeyVisual(char, false);
        }
    });

    key.addEventListener('mouseleave', () => {
        // Falls man die Maus bei gedrückter Taste rauszieht
        if (!isAudioStarted) return;
        const char = key.dataset.key;
        if (activeNotes[char]) {
            activeNotes[char].triggerRelease();
            delete activeNotes[char];
            toggleKeyVisual(char, false);
        }
    });
});