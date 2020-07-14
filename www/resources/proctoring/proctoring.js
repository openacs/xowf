// A class to implement lightweight student "proctoring" on
// browser-based applications.
//
// It works by grabbing audio or video input devices in this way:
//  1. audio - when an audio device is grabbed, any noise detected for
//             longer than a certain time time threshold will be made
//             into an opus-encoded webm audio file and passed to
//             configured callbacks
//  2. video - snapshots of configured video devices are captured from
//             the browser at random intervals in one or more of
//             configured image formats specified and passed to
//             configured callbacks
//
// Video capture supports still frame images (as jpeg or png) and also
// animated gifs created by concatenating all frames collected so
// far. Every image is automatically watermarked with current
// timestamp and can be configured to be converted to grayscale
// (useful to generate smaller files at the expense of colors).
//
// Dependencies: gif.js (http://jnordberg.github.io/gif.js/) (only to
// generate animated gifs)
//
// Author: Antonio Pisano (antonio@elettrotecnica.it)
//
// Usage: to start a proctored session, create a new Proctoring
// instance by by passing a configuration object to it.
//
// ## General Configuration Object Attributes ##
//
// - minMsInterval: applies to video stream grabbing. Min
//                  time interval to pass between two consecutive
//                  snapshots in milliseconds
// - maxMsInterval: applies to video stream grabbing. Max
//                  time interval to pass between twp consecutive
//                  snapshots in milliseconds
// - minAudioDuration: when audio is recorded, any noisy interval
//                    longer than this number of seconds will be
//                    transformed in an audio file
// - maxAudioDuration: when audio is recorded, recordings longer than
//                     this number of seconds will be stopped
//                     automatically so that no recordings will be
//                     longer than this value
// - onMissingStreamHandler: this javascript handler will be triggered
//                           when one on more of the required streams
//                           becomes unavailable during the proctoring
//                           session (e.g. user disconnects the
//                           camera, or other error
//                           condition). Receives in input
//                           'streamName', name of the failing stream
//                           and 'errMsg', returned error message.
// - onReadyHandler: this javascript handler is triggered as soon as
//                   the user has given access to all necessary input
//                   streams so that the proctored session can
//                   start. Does not receive any argument.
// - mediaConf: a JSON object that can have up to two attributes,
//              'camera', or 'desktop', to define the proctoring
//              behavior and multimedia input configuration for the
//              two kinds of devices. Each attribute's value is also a
//              JSON object, see ("Media Configuration Attributes" section).
//
// ## Media Configuration Attributes ##
//
// Each attribute 'camera' or 'desktop' from mediaConf supports the
// following attributes:
// - required: this boolean flag decides if the stream is required and
//             if proctoring should fail whenever this is not
//             available. Defaults to false
// - grayscale: boolean flag deciding if the captured images from this
//              stream should be converted to grayscale. Defaults to
//              false.
// - width / height: forced width and height. Tells the proctoring
//                   object that images from this stream should be
//                   forcefully rescaled to this size regardless of
//                   the size they were captured. Needed to create
//                   lower resolution images from devices
//                   (e.g. webcams) that cannot produce images this
//                   small, as some Apple cameras.
// - imageHandlers: a JSON object defining the handlers to be
//                  triggered whenever a new image from this stream is
//                  available. It supports 3 possible attributes, each
//                  named after the corresponding image type, 'png',
//                  'jpeg' and 'gif'. The presence of one of such
//                  attributes will enable the generation of an image
//                  in that type whenever a new snapshot is
//                  taken. Each attribue supports itself two possible
//                  attributes defining the handler type, 'blob', or
//                  'base64'. The value of each of those is a
//                  javascript handler that expects to receive the
//                  blob or base64 value respectively of the generated
//                  image.
// - audioHandlers: a JSON object currently supporting just one 'auto'
//                  attribute. The value of this attribute is a
//                  javascript handler called whenever a new audio
//                  recording is available, receiving the blob file
//                  containing the audio recording. When this
//                  attribute is missing, audio will not be recorded.
// - constraints: a MediaTrackConstraints JSON object defining the
//                real multimedia constraints for this device. See
//                https://developer.mozilla.org/en-US/docs/Web/API/MediaTrackConstraints
//
// Example conf:
//
// var conf = {
//     minMsInterval: 5000,
//     maxMsInterval: 10000,
//     minAudioDuration: 1,
//     maxAudioDuration: 60,
//     onMissingStreamHandler : function(streamName, errMsg) {
//         alert("'" + streamName + "' stream is missing. Please reload the page and enable all mandatory input sources.");
//     },
//     onReadyHandler : function(streamName, errMsg) {
//         console.log("All set!");
//     },
//     mediaConf: {
//         camera: {
//             required: true,
//             grayscale: true,
//             width: 320,
//             width: 240,
//             imageHandlers: {
//                    gif: {
//                        base64: function(base64data) {
//                            // this handler will be triggered
//                            // everytime a new gif for this stream is
//                            // rendered and will receive the base64
//                            // data in input
//                            var input = document.querySelector('input[name="proctoring1"]');
//                            input.value = base64data;
//                        }
//                    },
//                    png {
//                        blob: function(blob) {
//                            pushImageToServer(blob);
//                        }
//                    }
//             },
//             audioHandlers = {
//                   auto: function(blob) {
//                       // Do something with the audio blob
//                   }
//             },
//             constraints: {
//                 video: {
//                     width: { max: 640 },
//                     height: { max: 480 }
//                 }
//             }
//         },
//         desktop: {
//             required: true,
//             grayscale: false,
//             imageHandlers: {
//                    gif: {
//                        base64: function(base64data) {
//                            // this handler will be triggered
//                            // everytime a new gif for this stream is
//                            // rendered and will receive the base64
//                            // data in input
//                            var input = document.querySelector('input[name="proctoring1"]');
//                            input.value = base64data;
//                        }
//                    },
//                    png {
//                        base64: ...some handler
//                        blob:...
//                    },
//                    jpeg {
//                        ...
//                        ...
//                    }
//             },
//             constraints: {
//                 video: {
//                     width: { max: 640 },
//                     height: { max: 480 }
//                 }
//             }
//         }
//     }
// };
// var proctoring = new Proctoring(conf);
// proctoring.start();
//

Date.prototype.toTZISOString = function() {
    var tzo = -this.getTimezoneOffset(),
        dif = tzo >= 0 ? '+' : '-',
        pad = function(num) {
            var norm = Math.floor(Math.abs(num));
            return (norm < 10 ? '0' : '') + norm;
        };
    return this.getFullYear() +
        '-' + pad(this.getMonth() + 1) +
        '-' + pad(this.getDate()) +
        'T' + pad(this.getHours()) +
        ':' + pad(this.getMinutes()) +
        ':' + pad(this.getSeconds()) +
        dif + pad(tzo / 60) +
        ':' + pad(tzo % 60);
}

// Implements a recorder automatically grabbing audio samples when
// noise is detected for longer than a specified interval
class AutoAudioRecorder {
    constructor(stream, ondataavailable, minDuration=5, maxDuration=60, sampleInterval=50) {
        var autorec = this;
        this.stream = new MediaStream();
        var audioTracks = stream.getAudioTracks();
        if (audioTracks.length == 0) {
            throw "No audio track available in supplied stream";
        }

        // Get only audio tracks from the main stream object
        audioTracks.forEach(function(track) {
            autorec.stream.addTrack(track);
        });

        this.ondataavailable = ondataavailable;
        this.sampleInterval = sampleInterval;
        this.minDuration = minDuration;
        this.maxDuration = maxDuration;
        this.stopHandle = null;

        // Prepare to sample stream properties
        this.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        this.analyser = this.audioCtx.createAnalyser();
        this.source = this.audioCtx.createMediaStreamSource(this.stream);
        this.source.connect(this.analyser);
        this.analyser.fftSize = 2048;
        this.bufferLength = this.analyser.frequencyBinCount;
        this.dataArray = new Uint8Array(this.bufferLength);

        this.numPositiveSamples = 0;
        this.noise = 0;
        // Create an audio recorder
        this.recorder = new MediaRecorder(this.stream, {
            mimeType: 'audio/webm'
        });

        this.recorder.addEventListener("dataavailable", function(e) {
            if (autorec.currentDuration() >= autorec.minDuration) {
                autorec.ondataavailable(e.data);
            }
            autorec.numPositiveSamples = 0;
        });
    }

    currentDuration() {
        return (this.sampleInterval * this.numPositiveSamples) / 1000;
    }

    someNoise() {
        this.analyser.getByteTimeDomainData(this.dataArray);
        var max = 0;
        for(var i = 0; i < this.bufferLength; i++) {
            var v = (this.dataArray[i] - 128.0) / 128.0;
            if (v > max) {
                max = v;
            }
        }
        var decay = 500 / this.sampleInterval;
        this.noise = (this.noise * (decay - 1) + max) / decay;
        return max > 0.01;
    }

    silence() {
        // console.log(this.noise);
        return this.noise <= 0.01
    }

    autoRecord() {
        if (this.someNoise()) {
            if (this.recorder.state != "recording") {
                this.recorder.start();
            }
            this.numPositiveSamples++;
        } else if (this.recorder.state != "inactive" &&
                   this.silence()) {
            this.recorder.stop();
        }
        if (this.recorder.state != "inactive" &&
            this.currentDuration() >= this.maxDuration) {
            this.recorder.stop();
        }
    }

    start() {
        this.stop();
        this.stopHandle = setInterval(this.autoRecord.bind(this), this.sampleInterval);
    }

    stop() {
        if (this.stopHandle != null) {
            clearInterval(this.stopHandle);
        }
        if (this.recorder.state != "inactive") {
            this.recorder.stop();
        }
    }
}

class Proctoring {

    constructor(conf) {
        this.minMsInterval = conf.minMsInterval;
        this.maxMsInterval = conf.maxMsInterval;
        this.minAudioDuration = conf.minAudioDuration;
        this.maxAudioDuration = conf.maxAudioDuration;
        this.mediaConf = conf.mediaConf;

        this.streamNames = Object.keys(this.mediaConf);
        this.numStreams = this.streamNames.length;
        this.numCheckedStreams = 0;
        this.numActiveStreams = 0;

        this.onReadyHandler = conf.onReadyHandler;
        this.ready = false;
        this.onMissingStreamHandler = conf.onMissingStreamHandler;
        this.isMissingStreams = false;
        this.streamErrors = ["", ""];

        this.gifs = [null, null];
        this.imageHandlers = [null, null];
        this.audioHandlers = [null, null];
        this.pictures = [[], []];
        this.prevPictures = [null, null];
        this.streams = [null, null];
        this.videos = [null, null];

        for (var i = 0; i < this.numStreams; i++) {
            var conf = this.mediaConf[this.streamNames[i]]
            // streams are not required by default
            if (conf.required == undefined) {
                conf.required = false;
            }
            if (conf.imageHandlers != undefined) {
                this.imageHandlers[i] = conf.imageHandlers;
            }
            if (conf.audioHandlers != undefined) {
                this.audioHandlers[i] = conf.audioHandlers;
            }
        }

        this.acquireDevices();
    }

    acquireDevices() {
        var proctor = this;

        // Cam stream
        if (this.mediaConf.camera != undefined) {
            if (!navigator.mediaDevices.getUserMedia &&
                !navigator.getUserMedia) {
                var err = "getUserMedia not supported";
                proctor.streamErrors[proctor.streamNames.indexOf("camera")] = err;
                console.log("Camera cannot be recorded: " + err);
                proctor.numCheckedStreams++;
            } else {
                var camPromise = navigator.mediaDevices.getUserMedia ?
                    navigator.mediaDevices.getUserMedia(this.mediaConf.camera.constraints) :
                    navigator.getUserMedia(this.mediaConf.camera.constraints);
                camPromise.then(stream => {
                        var i = this.streamNames.indexOf("camera");
                        if (this.audioHandlers[i] != null) {
                            new AutoAudioRecorder(stream,
                                                  this.audioHandlers[i].auto,
                                                  this.minAudioDuration,
                                                  this.maxAudioDuration).start();
                        }
                        this.streams[i] = stream;
                        this.videos[i] = this.createVideo(stream);
                        this.numActiveStreams++;
                        this.numCheckedStreams++;
                    })
                    .catch(function (err) {
                        proctor.streamErrors[proctor.streamNames.indexOf("camera")] = err;
                        console.log("Camera cannot be recorded: " + err);
                        if (err.name == 'AbortError') {
                            proctor.numCheckedStreams = proctor.numStreams;
                        } else {
                            proctor.numCheckedStreams++;
                        }
                    });
            }
        }

        // Desktop stream
        if (this.mediaConf.desktop != undefined) {
            if (!navigator.mediaDevices.getDisplayMedia &&
                !navigator.getDisplayMedia) {
                var err = "getDisplayMedia not supported";
                proctor.streamErrors[proctor.streamNames.indexOf("desktop")] = err;
                console.log("Desktop cannot be recorded: " + err);
                proctor.numCheckedStreams++;
            } else {
                var desktopPromise = navigator.mediaDevices.getDisplayMedia ?
                    navigator.mediaDevices.getDisplayMedia(this.mediaConf.desktop.constraints) :
                    navigator.getDisplayMedia(this.mediaConf.desktop.constraints);
                desktopPromise.then(stream => {
                        var requestedStream = this.mediaConf.desktop.constraints.video.displaySurface;
                        var selectedStream = stream.getVideoTracks()[0].getSettings().displaySurface;
                        // If displaySurface was specified, browser
                        // MUST support it and MUST be the right one.
                        if (requestedStream == undefined ||
                            (selectedStream != undefined &&
                             requestedStream == selectedStream)) {
                            var i = this.streamNames.indexOf("desktop");
                            this.streams[i] = stream;
                            this.videos[i] = this.createVideo(stream);
                            this.numActiveStreams++;
                        } else {
                           throw "'" + requestedStream +"' was requested, but '" + selectedStream + "' was selected";
                        }
                        proctor.numCheckedStreams++;
                    })
                    .catch(function (err) {
                        proctor.streamErrors[proctor.streamNames.indexOf("desktop")] = err;
                        console.log("Desktop cannot be recorded: " + err);
                        if (err.name == 'AbortError') {
                            proctor.numCheckedStreams = proctor.numStreams;
                        } else {
                            proctor.numCheckedStreams++;
                        }
                    });
            }
        }
    }

    start() {
        this.checkMissingStreams();
        this.takePictures(this.minMsInterval, this.maxMsInterval);
    }

    reset() {
        this.pictures = [[], []];
    }

    streamMuted(stream) {
        var muted = false;
        var audioTracks = stream.getAudioTracks();
        for (var i = 0; i < audioTracks.length; i++) {
            var track = audioTracks[i];
            if (track.muted ||
                !track.enabled ||
                track.getSettings().volume == 0) {
                muted = true;
                break;
            }
        }
        var videoTracks = stream.getVideoTracks();
        for (var i = 0; i < videoTracks.length; i++) {
            var track = videoTracks[i];
            if (track.muted ||
                !track.enabled) {
                muted = true;
                break;
            }
        }
        return muted;
    }

    checkStream(stream, streamName) {
        if (stream == null ||
            !stream.active ||
            this.streamMuted(stream)) {
            if (this.mediaConf[streamName].required) {
                return false;
            }
        }
        return true;
    }

    checkMissingStreams() {
        if (!this.isMissingStreams &&
            this.numCheckedStreams == this.numStreams) {
            for (var i = 0; i < this.streams.length; i++) {
                var streamName = this.streamNames[i];
                if (!this.checkStream(this.streams[i], streamName)) {
                    this.isMissingStreams = true;
                    if (typeof this.onMissingStreamHandler == 'function') {
                        var err = this.streamErrors[i];
                        this.onMissingStreamHandler(streamName, err);
                    }
                }
            }
        }

        if (!this.isMissingStreams) {
            setTimeout(this.checkMissingStreams.bind(this), 1000);
        }
    }

    renderGif(frames) {
        if (frames.length == 0) {
            return;
        }
        var i = this.pictures.indexOf(frames);
        if (this.gifs[i] == null) {
            this.gifs[i] = new GIF({
                workers: 2,
                quality: 30,
                workerScript: Proctoring.webWorkerURL,
                width: frames[0].width,
                height: frames[0].height
            });
            var proctor = this;
            var gifs = this.gifs;
            gifs[i].on('finished', function(blob) {
                var handlers = proctor.imageHandlers[i];
                if (typeof handlers.gif.blob == 'function') {
                    handlers.gif.blob(blob);
                }
                if (typeof handlers.gif.base64 == 'function') {
                    var reader = new FileReader();
                    reader.readAsDataURL(blob);
                    reader.onloadend = function() {
                        var base64data = reader.result;
                        handlers.gif.base64(base64data);
                    }
                }
                // Stop the workers and kill the gif object
                this.abort();
                this.freeWorkers.forEach(w => w.terminate());
                gifs[gifs.indexOf(this)] = null;
            });
        }
        var gif = this.gifs[i];
        if (!gif.running) {
            for (var j = 0; j < frames.length; j++) {
                gif.addFrame(frames[j], {delay: 500});
            }
            gif.render();
        }
    }

    createVideo(stream) {
        var video = document.createElement("video");
        video.muted = true;
        video.autoplay = "true";
        video.preload = "auto";
        video.srcObject = stream;
        video.addEventListener("loadeddata", function(e) {
            if (this.paused) {
                this.play();
            }
        });
        // Try to force that video is never put to sleep
        video.addEventListener("pause", function(e) {
            this.play();
        });

        return video;
    }

    watermark(canvas, text) {
        var ctx = canvas.getContext("2d");
        var fontSize = 0.032*canvas.width;
        ctx.font = "10px monospace" ;
        ctx.fillStyle = "white";
        ctx.strokeStyle = "black";
        ctx.lineWidth = 0.5;
        var metrics = ctx.measureText(text);
        var x = canvas.width - metrics.width;
        var y = canvas.height - fontSize;
        ctx.fillText(text, x, y);
        ctx.strokeText(text, x, y);
    }

    canvasToGrayscale(canvas) {
        var ctx = canvas.getContext("2d");
        var imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        var data = imageData.data;
        for (var i = 0; i < data.length; i += 4) {
            var avg = (data[i] + data[i + 1] + data[i + 2]) / 3;
            data[i]     = avg; // red
            data[i + 1] = avg; // green
            data[i + 2] = avg; // blue
        }
        ctx.putImageData(imageData, 0, 0);
    }

    isCanvasMonochrome(canvas) {
        var ctx = canvas.getContext("2d");
        var imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
        var data = imageData.data;
        var isMonochrome = true;
        var firstPx = [];
        for (var i = 0; i < data.length; i += 4) {
            if (i == 0) {
                firstPx[0] = data[i];
                firstPx[1] = data[i+1];
                firstPx[2] = data[i+2];
            } else if (firstPx[0] != data[i] ||
                       firstPx[1] != data[i+1] ||
                       firstPx[2] != data[i+2]) {
                isMonochrome = false;
                break;
            }
        }

        return isMonochrome;
    }

    areCanvasEquals(canvas1, canvas2) {
        var ctx1 = canvas1.getContext("2d");
        var imageData1 = ctx1.getImageData(0, 0, canvas1.width, canvas1.height);
        var data1 = imageData1.data;
        var ctx2 = canvas2.getContext("2d");
        var imageData2 = ctx2.getImageData(0, 0, canvas2.width, canvas2.height);
        var data2 = imageData2.data;
        var areEquals = true;
        for (var i = 0; i < data1.length; i += 4) {
            if (data1[i] != data2[i] ||
                data1[i+1] != data2[i+1] ||
                data1[i+2] != data2[i+2]) {
                areEquals = false;
                break;
            }
        }

        return areEquals;
    }


    takeShot(stream, grayscale) {
        var i = this.streams.indexOf(stream);
        var video = this.videos[i];

        if (!video.paused) {
            var streamName = this.streamNames[i];
            var conf = this.mediaConf[streamName];
            // var height = stream.getVideoTracks()[0].getSettings().height;
            // var width = stream.getVideoTracks()[0].getSettings().width;
            var iHeight = conf.height == undefined ? video.videoHeight : conf.height;
            var iWidth = conf.width == undefined ? video.videoWidth : conf.width;
            var proctor = this;
            var pictures = this.pictures[i];
            var prevPicture = this.prevPictures[i];

            var canvas = document.createElement("canvas");
            canvas.width = iWidth;
            canvas.height = iHeight;
            canvas.getContext("2d").drawImage(video, 0, 0, iWidth, iHeight);

            // In the future we might be stricter about black pictures...
            // if (this.isCanvasMonochrome(canvas)) {
            //     var err = "canvas is monochrome";
            //     this.onMissingStreamHandler(streamName, err);
            //     return;
            // }

            // Check that camera does not keep sending the same
            // picture over and over.
            if (streamName == "camera" &&
                prevPicture != null &&
                this.areCanvasEquals(canvas, prevPicture)) {
                var err = "camera is stuck";
                this.onMissingStreamHandler(streamName, err);
                return;
            }
            this.prevPictures[i] = canvas;

            if (grayscale) {
                this.canvasToGrayscale(canvas);
            }

            this.watermark(canvas, (new Date()).toTZISOString());

            var handlers = proctor.imageHandlers[i];
            if (handlers != null) {
                if (handlers.png != undefined) {
                    canvas.toBlob(function(blob) {
                        if (typeof handlers.png.blob == 'function') {
                            handlers.png.blob(blob);
                        }
                        if (typeof handlers.png.base64 == 'function') {
                            var reader = new FileReader();
                            reader.readAsDataURL(blob);
                            reader.onloadend = function() {
                                var base64data = reader.result;
                                handlers.png.base64(base64data);
                            }
                        }
                    }, "image/png");
                }
                if (handlers.jpeg != undefined) {
                    canvas.toBlob(function(blob) {
                        if (typeof handlers.jpeg.blob == 'function') {
                            handlers.jpeg.blob(blob);
                        }
                        if (typeof handlers.jpeg.base64 == 'function') {
                            var reader = new FileReader();
                            reader.readAsDataURL(blob);
                            reader.onloadend = function() {
                                var base64data = reader.result;
                                handlers.jpeg.base64(base64data);
                            }
                        }
                    }, "image/jpeg");
                }
                if (handlers.gif != undefined) {
                    pictures.push(canvas);
                    proctor.renderGif(pictures);
                }
            }
        }
    }

    takePictures(minMsInterval, maxMsInterval) {
        var interval;
        if (!this.isMissingStreams &&
            this.numCheckedStreams == this.numStreams &&
            this.numActiveStreams > 0) {
            // User already gave access to all requested streams and
            // proctoring has successfully started
            if (!this.ready) {
                // If this is the first picture we take for this
                // session, take not of this and trigger the onReady
                // handler
                if (typeof this.onReadyHandler == 'function') {
                    this.onReadyHandler();
                }
                this.ready = true;
            }
            // For every configured stream, take a picture
            for (var i = 0; i < this.streams.length; i++) {
                if (this.streams[i] != null) {
                    this.takeShot(this.streams[i], this.mediaConf[this.streamNames[i]].grayscale);
                }
            }
            // Set the time to the next snapshot to a random interval
            interval = (Math.random() * (maxMsInterval - minMsInterval)) + minMsInterval;
        } else {
            // Not all streams are available and we cannot take
            // snapshots (yet?). Set interval one second from now.
            interval = 1000;
            console.log("Waiting for streams: " + this.numCheckedStreams + "/" + this.numStreams + " ready.");
        }
        if (!this.isMissingStreams) {
            // No errors, reschedule this function for the computed
            // interval
            setTimeout(this.takePictures.bind(this), interval, minMsInterval, maxMsInterval);
        } else {
            // Something went wrong and proctoring cannot proceed
            console.log("Stopping...");
        }
    }
}

// We need this trick to get the folder of this very script and build
// from there the URL to the gif worker.
var scripts = document.querySelectorAll("script");
var loc = scripts[scripts.length - 1].src;
Proctoring.webWorkerURL = loc.substring(0, loc.lastIndexOf('/')) + "/gif.worker.js";
