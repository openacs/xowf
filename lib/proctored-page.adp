<master>
  <property name="show_header">1</property>
  <property name="side_menu">0</property>
  <property name="show_title">0</property>
  <property name="show_community_title">0</property>

  <script src="/resources/xowf/proctoring/gif.js"></script>
  <script src="/resources/xowf/proctoring/proctoring.js"></script>
  <!-- <script src="/resources/xowf/proctoring/audiowave.js"></script> -->

  <div class="row info_proctoring" style="background:red; text-align:center;padding:0px;">
      <h5 style='color:white;text-align:center;display: inline-block;'>@msg.proctoring_banner@</h5>
      <if @preview_p;literal@ true>
    <div id="preview-placeholder" style='float: right; padding: 0px;'>
      <!--<canvas id="audio-preview" style="height: 30px; width: 40px"></canvas>-->
    </div>
      </if>
  </div>

  <div id="proctored-iframe-placeholder" class="embed-responsive embed-responsive-16by9"></div>
  <div id="confirm-dialog" class="modal" tabindex="-1" role="dialog" data-backdrop="static" data-keyboard="false">
    <div class="modal-dialog" role="document">
      <div class="modal-content">
    <div class="modal-body">
          <if @proctoring_p;literal@ true>
            <p>@msg.proctoring_accept@</p>
          </if>
          <if @examination_statement_p;literal@ true>
            <p>@msg.exam_mode;literal@</p>
          </if>      
    </div>
    <div class="modal-footer">
      <button id="confirm-button" type="button" class="btn btn-primary" data-dismiss="modal">@msg.accept@</button>
    </div>
      </div>
    </div>
  </div>

  <script <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce@"</if>>
     window.addEventListener("load", function() {
    function createIframe() {
        var iframe = document.createElement("iframe");
        iframe.setAttribute("class", "embed-responsive-item");
        iframe.setAttribute("id", "proctored-iframe-@object_id@");
        iframe.addEventListener("load", function(e) {
        // Prevent loops of iframes: bring the iframe to the
        // start when we detect it would land on the very URL
        // of this page
        var parentURL = location.href + location.search;
        var iframeURL = this.contentWindow.location.href + this.contentWindow.location.search;
        if (parentURL == iframeURL) {
            this.src = "@object_url;literal@";
        }
        });
        document.querySelector("#proctored-iframe-placeholder").appendChild(iframe);
        iframe.src = "@object_url;literal@";
    }

    function createPreview() {
        var style;
        var e = document.querySelector("#preview-placeholder");
        // style = !@preview_p;literal@ ? "position:absolute;top:0;left:0;" : "";
        // e.setAttribute("style", style);
        // var canvas = document.createElement("canvas");
        // style = @preview_p;literal@ ? "height: 30px; width: 40px" : "height: 1px; width: 1px";
        // canvas.setAttribute("style", style);    
        // canvas.setAttribute("id", "audio-preview");
        // e.appendChild(canvas);
        var e = document.querySelector("#preview-placeholder");
        for (var i = 0; i < 1 /* proctoring.videos.length*/; i++) {
            var video = proctoring.videos[i];
            video.setAttribute("height", @preview_p;literal@ ? 40 : 1);
            e.appendChild(video);
        }
    }

    var uploadQueue = [];
    function scheduleUpload(name, type, blob) {
        console.log("SCHED UPLOAD " + name + " " + type + " to: " + "@upload_url@");

        var formData = new FormData();
        formData.append("name", name);
        formData.append("type", type);
        formData.append("object_id", @object_id@);
        formData.append("file", blob);
        uploadQueue.push(formData);
    }

    function upload() {
        if (uploadQueue.length > 0) {
            var formData = uploadQueue.shift();
            var request = new XMLHttpRequest();
            request.timeout = 10000;
            request.addEventListener("readystatechange", function () {
                if (this.readyState == 4) {
                    if (this.status == 200) {
                        if (this.response == "OK") {
                            setTimeout(upload);
                        } else if (this.response == "OFF") {
                            location.href = '@object_url;literal@';
                        }
                    } else {
                        uploadQueue.unshift(formData);
                        setTimeout(upload, 10000);
                    }
                }
            });
            request.open("POST", "@upload_url@");
            request.send(formData);
        } else {
            setTimeout(upload, 1000);
        }
    }

    var audioHandlers;
    if (@audio_p@) {
        audioHandlers = {
            auto: function(blob) {
                scheduleUpload("camera", "audio", blob);
            }
        };
    };

    var conf = {
        minMsInterval: @min_ms_interval@,
        maxMsInterval: @max_ms_interval@,
        minAudioDuration: @min_audio_duration@,
        maxAudioDuration: @max_audio_duration@,
        onMissingStreamHandler : function(streamName, errMsg) {
            alert("@msg.missing_stream@ " + " stream: " + streamName + " error: " + errMsg);
            location.reload();
        },
        onReadyHandler: function() {
            createIframe();
	    createPreview();
        },
        mediaConf: {
            camera: {
                required: true,
                grayscale: true,
                width: 320,
                height: 240,
                imageHandlers: {
                    jpeg: {
                        blob: function(blob) {
                            scheduleUpload("camera", "image", blob);
                        }
                    }
                },
                audioHandlers: audioHandlers,
                constraints: {
                    video: {
                        width: { max: 640 },
                        height: { max: 480 }
                    },
                    audio: true
                }
            },
            desktop: {
                required: true,
                grayscale: false,
		//width: 1024, //960, //800, //720,
                //height: 768, //540, //600, //480,
                imageHandlers: {
                    jpeg: {
                        blob: function(blob) {
                            scheduleUpload("desktop", "image", blob);
                        }
                    }
                },
                constraints: {
                    video: {
                        //width: { min: 1024, max: 1280 },
                        //height: { min: 768, max: 960 },
			width: 1280,
			height: 969,			
                        displaySurface: "monitor"
                    },
                    audio: false
                }
            }
        }
    };

    function startExam() {
        if (!@mobile_p;literal@) {
            if (@proctoring_p;literal@) {
                console.log("creating proctoring");
                proctoring = new Proctoring(conf);
                console.log("starting proctoring");
                proctoring.start();
                console.log("starting upload");
                upload();
                console.log("proctoring has started");
            } else {
                createIframe();
                console.log("proctoring not requested");
            }
        } else {
            alert("Mobile devices are unsupported");
        }
    }
	
    function approveStartExam() {
        var formData = new FormData();
        formData.append("object_id", @object_id;literal@);
        var request = new XMLHttpRequest();
        request.timeout = 10000;
        request.addEventListener("readystatechange", function () {
            if (this.readyState == 4) {
                if (this.status == 200) {
                    if (this.response == "OK") {
                        startExam();
                    } else {
                        location.href = '@object_url;literal@';
                    }
                } else {
                    console.log("Request has failed with status: " + this.status + "... Retry in 10s");
                    setTimeout(approveStartExam, 10000);
                }
            }
        });
        request.open("POST", "@examination_statement_url@");
        request.send(formData);
    }
    
    document.querySelector("#confirm-button").addEventListener("click", function(e) {
        if (@examination_statement_p;literal@ && "@examination_statement_url;literal@" != "") {
            approveStartExam();
        } else {
            startExam();
        }
    });
    
    $("#confirm-dialog").modal('show');
    });
    </script>
