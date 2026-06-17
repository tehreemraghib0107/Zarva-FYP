// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

/// Chrome/web AR pipeline — MediaPipe Face Mesh + Pose with landmark 234/454/152 tracking.
class ArWebBridge {
  static bool _initialized = false;

  static Future<void> ensureScriptsLoaded() async {
    if (_initialized) return;

    final urls = [
      'https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js',
      'https://cdn.jsdelivr.net/npm/@mediapipe/control_utils/control_utils.js',
      'https://cdn.jsdelivr.net/npm/@mediapipe/drawing_utils/drawing_utils.js',
      'https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/face_mesh.js',
      'https://cdn.jsdelivr.net/npm/@mediapipe/pose/pose.js',
    ];

    for (final url in urls) {
      await _injectScript(url);
    }
    _injectBridgeScript();
    _initialized = true;
  }

  static Future<void> _injectScript(String src) {
    final completer = Completer<void>();
    final script = html.ScriptElement()
      ..type = 'text/javascript'
      ..src = src
      ..async = false;
    script.onLoad.listen((_) => completer.complete());
    script.onError.listen((_) => completer.completeError(Exception('Failed: $src')));
    html.document.head?.append(script);
    return completer.future;
  }

  static void _injectBridgeScript() {
    final script = html.ScriptElement()..type = 'text/javascript';
    script.text = r'''
(function(){
  window.arTryOnRegistry = window.arTryOnRegistry || {};
  window.arTryOnErrors = window.arTryOnErrors || {};

  var LEFT_EAR = 234;
  var RIGHT_EAR = 454;
  var CHIN = 152;
  var FOREHEAD = 10;
  var JAW_LEFT = 132;
  var JAW_RIGHT = 361;

  function wait(ms){ return new Promise(function(r){ setTimeout(r, ms); }); }

  async function waitForElement(id, timeoutMs){
    var start = Date.now();
    while(Date.now() - start < timeoutMs){
      var el = document.getElementById(id);
      if(el) return el;
      await wait(50);
    }
    return null;
  }

  function lerp(a,b,t){ return a + (b-a)*t; }
  function lerpPt(a,b,t){ return { x: lerp(a.x,b.x,t), y: lerp(a.y,b.y,t) }; }

  function mapVideoPoint(registry, x, y){
    var c = registry.container, v = registry.video;
    var cw = c.clientWidth || 640, ch = c.clientHeight || 480;
    var vw = v.videoWidth || 640, vh = v.videoHeight || 480;
    var scale = Math.max(cw/vw, ch/vh);
    var sw = vw*scale, sh = vh*scale;
    var ox = (cw-sw)/2, oy = (ch-sh)/2;
    return { x: ox + (vw-x)*scale, y: oy + y*scale, scale: scale };
  }

  function supportsCategory(cat){
    var c = (cat||'').toLowerCase();
    return c.includes('earring')||c.includes('necklace')||c.includes('choker')||c.includes('locket');
  }

  function loadImage(src){
    return new Promise(function(resolve){
      var img = new Image();
      img.crossOrigin = 'anonymous';
      img.onload = function(){ resolve(img); };
      img.onerror = function(){ resolve(null); };
      img.src = src;
    });
  }

  function estimateRoll(lm){
    var le = lm[LEFT_EAR], re = lm[RIGHT_EAR];
    if(!le||!re) return 0;
    return Math.atan2(re.y-le.y, re.x-le.x);
  }

  function renderFrame(registry){
    if(!registry.jewelryImage || !registry.faceLandmarks) return;
    var ctx = registry.overlayCtx;
    var canvas = registry.overlayCanvas;
    canvas.width = registry.container.clientWidth || 640;
    canvas.height = registry.container.clientHeight || 640;
    ctx.clearRect(0,0,canvas.width,canvas.height);

    var lm = registry.faceLandmarks;
    var vw = registry.video.videoWidth || 640;
    var vh = registry.video.videoHeight || 480;
    
    var le = lm[LEFT_EAR], re = lm[RIGHT_EAR], chin = lm[CHIN], forehead = lm[FOREHEAD];
    if(!le||!re||!chin||!forehead) return;

    var rawFaceWidth = Math.abs(re.x - le.x) * vw * mapVideoPoint(registry,0,0).scale;
    registry.smooth.faceWidth = registry.smooth.faceWidth === 0
      ? rawFaceWidth : lerp(registry.smooth.faceWidth, rawFaceWidth, 0.25);
    var faceWidth = registry.smooth.faceWidth;
    var faceHeight = faceWidth * 1.15;
    var roll = estimateRoll(lm);
    var cat = (registry.productCategory||'').toLowerCase();

    if(cat.includes('earring')){
      var dangle = faceHeight * 0.06 / mapVideoPoint(registry,0,0).scale;
      var leftRaw = mapVideoPoint(registry, le.x*vw, le.y*vh + dangle);
      var rightRaw = mapVideoPoint(registry, re.x*vw, re.y*vh + dangle);
      registry.smooth.leftEar = registry.smooth.leftEar
        ? lerpPt(registry.smooth.leftEar, leftRaw, 0.25) : leftRaw;
      registry.smooth.rightEar = registry.smooth.rightEar
        ? lerpPt(registry.smooth.rightEar, rightRaw, 0.25) : rightRaw;
      
      // Dynamic Head-Scale Baseline (Distance between chin 152 and forehead 10)
      var foreheadMapped = mapVideoPoint(registry, forehead.x*vw, forehead.y*vh);
      var chinMapped = mapVideoPoint(registry, chin.x*vw, chin.y*vh);
      var headScale = Math.sqrt(Math.pow(chinMapped.x - foreheadMapped.x, 2) + Math.pow(chinMapped.y - foreheadMapped.y, 2));
      
      // Scale height of the earring directly proportional to headScale baseline
      var earringHeight = headScale * 0.20;

      drawJewelry(ctx, registry.jewelryImage, registry.smooth.leftEar, earringHeight, roll, false, false);
      drawJewelry(ctx, registry.jewelryImage, registry.smooth.rightEar, earringHeight, roll, false, true);
    } else {
      var chinMapped = mapVideoPoint(registry, chin.x*vw, chin.y*vh);
      var jawL = lm[JAW_LEFT], jawR = lm[JAW_RIGHT];
      if(!jawL || !jawR) return;
      var jawLMapped = mapVideoPoint(registry, jawL.x*vw, jawL.y*vh);
      var jawRMapped = mapVideoPoint(registry, jawR.x*vw, jawR.y*vh);

      var plm = registry.poseLandmarks;
      var shLMapped, shRMapped;
      if (plm && plm[11] && plm[12]) {
        shLMapped = mapVideoPoint(registry, plm[11].x*vw, plm[11].y*vh);
        shRMapped = mapVideoPoint(registry, plm[12].x*vw, plm[12].y*vh);
      } else {
        // Fallback: estimate shoulders relative to jaw
        shLMapped = { x: jawLMapped.x, y: jawLMapped.y + faceHeight * 0.8 };
        shRMapped = { x: jawRMapped.x, y: jawRMapped.y + faceHeight * 0.8 };
      }

      // Compute the dynamic width of the user's actual neck base region (45% between jaw and shoulder)
      var tNeck = 0.45;
      var neckBaseL = {
        x: lerp(jawLMapped.x, shLMapped.x, tNeck),
        y: lerp(jawLMapped.y, shLMapped.y, tNeck)
      };
      var neckBaseR = {
        x: lerp(jawRMapped.x, shRMapped.x, tNeck),
        y: lerp(jawRMapped.y, shRMapped.y, tNeck)
      };
      var neckWidth = Math.sqrt(Math.pow(neckBaseR.x - neckBaseL.x, 2) + Math.pow(neckBaseR.y - neckBaseL.y, 2));

      // Estimate shoulder base center
      var shoulderCenter = {
        x: (shLMapped.x + shRMapped.x) / 2,
        y: (shLMapped.y + shRMapped.y) / 2
      };

      // Vector from chin to shoulder center defines neck axis
      var neckDx = shoulderCenter.x - chinMapped.x;
      var neckDy = shoulderCenter.y - chinMapped.y;

      // Tight static offset upward toward throat for chokers, lower on collarbone plane for necklaces
      var tOffset = cat.includes('choker') ? 0.22 : 0.68;
      var neckRaw = {
        x: chinMapped.x + tOffset * neckDx,
        y: chinMapped.y + tOffset * neckDy
      };

      registry.smooth.neck = registry.smooth.neck
        ? lerpPt(registry.smooth.neck, neckRaw, 0.25) : neckRaw;
      
      // Enforce necklace width to exactly 1.15x the neckWidth
      var width = neckWidth * 1.15;
      drawJewelry(ctx, registry.jewelryImage, registry.smooth.neck, width, roll, true, false);
    }
  }

  function drawJewelry(ctx, img, pos, size, roll, isNecklace, isRight){
    ctx.save();
    ctx.translate(pos.x, pos.y);
    ctx.rotate(roll);
    if (isRight) {
      ctx.scale(-1, 1);
    }
    ctx.shadowColor = 'rgba(0,0,0,0.38)';
    ctx.shadowBlur = 10;
    
    var w, h;
    if(isNecklace){
      w = size;
      h = w * (img.height / img.width);
      ctx.drawImage(img, -w/2, -h*0.3, w, h);
    } else {
      h = size; // earring height
      w = h * (img.width / img.height);
      ctx.drawImage(img, -w/2, 0, w, h);
    }
    ctx.restore();
  }

  window.arTryOnStopAll = function(){
    Object.keys(window.arTryOnRegistry||{}).forEach(function(id){ window.arTryOnStop(id); });
  };

  window.arTryOnStop = function(containerId){
    var r = window.arTryOnRegistry[containerId];
    if(!r) return;
    if(r.faceMesh && r.faceMesh.close) try{ r.faceMesh.close(); }catch(e){}
    if(r.pose && r.pose.close) try{ r.pose.close(); }catch(e){}
    if(r.camera && r.camera.stop) try{ r.camera.stop(); }catch(e){}
    if(r.stream) r.stream.getTracks().forEach(function(t){ t.stop(); });
    if(r.container) r.container.innerHTML = '';
    delete window.arTryOnRegistry[containerId];
    delete window.arTryOnErrors[containerId];
  };

  window.arTryOnIsReady = function(id){
    var r = window.arTryOnRegistry[id];
    return !!(r && r.ready);
  };

  window.arTryOnGetError = function(id){
    return window.arTryOnErrors[id] || null;
  };

  window.arTryOnInit = async function(containerId, productCategory, productImageUrl){
    try {
      window.arTryOnStopAll();
      delete window.arTryOnErrors[containerId];

      var container = await waitForElement(containerId, 6000);
      if(!container){
        window.arTryOnErrors[containerId] = 'Camera view failed to mount.';
        return;
      }
      if(!supportsCategory(productCategory)){
        window.arTryOnErrors[containerId] = 'AR supports earrings, necklaces, chokers, and lockets.';
        return;
      }

      container.innerHTML = '';
      container.style.position = 'relative';
      container.style.overflow = 'hidden';
      container.style.background = '#000';

      var video = document.createElement('video');
      var overlayCanvas = document.createElement('canvas');
      video.autoplay = true; video.playsInline = true; video.muted = true;
      video.style.width = '100%'; video.style.height = '100%';
      video.style.objectFit = 'cover'; video.style.transform = 'scaleX(-1)';
      overlayCanvas.style.position = 'absolute'; overlayCanvas.style.top = '0'; overlayCanvas.style.left = '0';
      overlayCanvas.style.width = '100%'; overlayCanvas.style.height = '100%';
      overlayCanvas.style.pointerEvents = 'none'; overlayCanvas.style.zIndex = '12';
      container.appendChild(video);
      container.appendChild(overlayCanvas);

      var jewelryImage = await loadImage(productImageUrl);
      if(!jewelryImage){
        window.arTryOnErrors[containerId] = 'Could not load jewelry overlay image.';
        return;
      }

      var stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: { ideal: 1280 }, height: { ideal: 720 } },
        audio: false
      });
      video.srcObject = stream;
      await video.play();
      await wait(120);

      var registry = {
        container: container,
        video: video,
        overlayCanvas: overlayCanvas,
        overlayCtx: overlayCanvas.getContext('2d'),
        jewelryImage: jewelryImage,
        stream: stream,
        faceLandmarks: null,
        poseLandmarks: null,
        productCategory: productCategory,
        smooth: { leftEar: null, rightEar: null, neck: null, faceWidth: 0 },
        ready: false
      };
      window.arTryOnRegistry[containerId] = registry;

      var faceMesh = new FaceMesh({
        locateFile: function(f){ return 'https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/'+f; }
      });
      faceMesh.setOptions({ maxNumFaces: 1, refineLandmarks: true, minDetectionConfidence: 0.6, minTrackingConfidence: 0.6 });

      var pose = new Pose({
        locateFile: function(f){ return 'https://cdn.jsdelivr.net/npm/@mediapipe/pose/'+f; }
      });
      pose.setOptions({ modelComplexity: 1, smoothLandmarks: true, minDetectionConfidence: 0.5, minTrackingConfidence: 0.5 });

      registry.faceMesh = faceMesh;
      registry.pose = pose;

      faceMesh.onResults(function(res){
        registry.faceLandmarks = res.multiFaceLandmarks && res.multiFaceLandmarks.length
          ? res.multiFaceLandmarks[0] : null;
        renderFrame(registry);
      });
      pose.onResults(function(res){
        registry.poseLandmarks = res.poseLandmarks || null;
        renderFrame(registry);
      });

      var camera = new Camera(video, {
        onFrame: async function(){
          await faceMesh.send({ image: video });
          await pose.send({ image: video });
        },
        width: video.videoWidth || 1280,
        height: video.videoHeight || 720
      });
      await camera.start();
      registry.camera = camera;
      registry.ready = true;
    } catch(err) {
      window.arTryOnErrors[containerId] = err && err.message ? err.message : 'Camera access failed.';
    }
  };
})();
''';
    html.document.head?.append(script);
  }

  static Future<void> initPipeline(
    String containerId,
    String productCategory,
    String productImageUrl,
  ) async {
    js.context.callMethod('arTryOnInit', [containerId, productCategory, productImageUrl]);

    for (var i = 0; i < 80; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      final error = js.context.callMethod('arTryOnGetError', [containerId]);
      if (error != null && error.toString().isNotEmpty) {
        throw Exception(error.toString());
      }
      if (js.context.callMethod('arTryOnIsReady', [containerId]) == true) return;
    }
    throw Exception('AR camera timed out.');
  }

  static void stopPipeline(String containerId) {
    js.context.callMethod('arTryOnStop', [containerId]);
  }

  static void registerViewFactory(String viewType, String containerId) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      return html.DivElement()
        ..id = containerId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.position = 'relative'
        ..style.backgroundColor = '#000';
    });
  }
}
