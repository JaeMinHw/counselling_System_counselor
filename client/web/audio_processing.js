function startAudioProcessing() {
    navigator.mediaDevices.getUserMedia({ audio: true }).then(function (stream) {
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const source = audioContext.createMediaStreamSource(stream);
        const analyser = audioContext.createAnalyser();
        const scriptProcessor = audioContext.createScriptProcessor(2048, 1, 1);

        source.connect(analyser);
        analyser.connect(scriptProcessor);
        scriptProcessor.connect(audioContext.destination);

        let isSpeaking = false;
        let silenceStartTime = null;
        const silenceDurationThreshold = 1000; // 1초 (1000ms)

        scriptProcessor.onaudioprocess = function () {
            const audioData = new Float32Array(analyser.fftSize);
            analyser.getFloatTimeDomainData(audioData);

            const isSilent = audioData.every(value => Math.abs(value) < 0.02);

            if (isSilent) {
                if (isSpeaking) {
                    if (!silenceStartTime) {
                        silenceStartTime = Date.now();
                    } else if (Date.now() - silenceStartTime > silenceDurationThreshold) {
                        window.dispatchEvent(new Event('audioStopped'));
                        isSpeaking = false;
                        silenceStartTime = null;
                    }
                }
            } else {
                if (!isSpeaking) {
                    window.dispatchEvent(new Event('audioStarted'));
                    isSpeaking = true;
                }
                silenceStartTime = null;
            }
        };
    }).catch(function (error) {
        console.error("Error accessing audio devices: ", error);
    });
}
