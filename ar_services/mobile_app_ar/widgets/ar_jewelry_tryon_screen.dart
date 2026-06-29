import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Production-ready 3D AR jewelry try-on widget using Three.js + MediaPipe.
///
/// Embeds a high-performance JavaScript-based AR view with:
/// - Real-time face mesh tracking (MediaPipe)
/// - 3D model anchoring (Three.js + GLTFLoader)
/// - Temporal smoothing filters for stable placement
/// - Auto-scaling and rotation adjustment
class ArJewelryTryOnScreen extends StatefulWidget {
  /// URL to the 3D earrings model (GLB format)
  final String earringsModelUrl;

  /// URL to the 3D necklace model (GLB format)
  final String necklaceModelUrl;

  /// Optional product name for display
  final String? productName;

  /// Asset base path (if models are served from relative path, e.g., 'assets/')
  /// Useful for Flutter web asset hosting
  final String? assetBasePath;

  /// Enable debug overlay with FPS and landmark info
  final bool debugMode;

  const ArJewelryTryOnScreen({
    Key? key,
    this.earringsModelUrl = 'https://example.com/models/earrings.glb',
    this.necklaceModelUrl = 'https://example.com/models/necklace.glb',
    this.productName,
    this.assetBasePath,
    this.debugMode = false,
  }) : super(key: key);

  @override
  State<ArJewelryTryOnScreen> createState() => _ArJewelryTryOnScreenState();
}

class _ArJewelryTryOnScreenState extends State<ArJewelryTryOnScreen> {
  late final String _viewId;
  final String _iframeIdPrefix = 'ar-iframe-';
  bool _isModelLoaded = false;
  String _status = 'Initializing AR...';

  @override
  void initState() {
    super.initState();
    assert(kIsWeb, 'ArJewelryTryOnScreen only works on Flutter Web (Chrome).');
    _viewId = 'ar-view-${DateTime.now().millisecondsSinceEpoch}';
    _registerViewFactory();
  }

  void _registerViewFactory() {
    final String srcDoc = _generateHtmlContent();

    final html.IFrameElement iframe = html.IFrameElement()
      ..id = '$_iframeIdPrefix$_viewId'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..srcdoc = srcDoc
      ..allow =
          'camera; microphone; autoplay; clipboard-write; encrypted-media;'
      ..allowFullscreen = true;

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      return iframe;
    });
  }

  String _generateHtmlContent() {
    // Resolve asset URLs: support both CDN URLs and local asset paths
    final earringsUrl = widget.assetBasePath != null
        ? '${widget.assetBasePath}earrings.glb'
        : widget.earringsModelUrl;

    final necklaceUrl = widget.assetBasePath != null
        ? '${widget.assetBasePath}necklace.glb'
        : widget.necklaceModelUrl;

    final debugMode = widget.debugMode ? 'true' : 'false';

    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>AR Jewelry Try-On</title>

  <!-- MediaPipe (FaceMesh) -->
  <script src="https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh@0.4/face_mesh.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/@mediapipe/drawing_utils/drawing_utils.js"></script>

  <!-- Three.js + GLTFLoader -->
  <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r152/three.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/three@0.152.2/examples/js/loaders/GLTFLoader.js"></script>

  <style>
    html, body {
      margin: 0; padding: 0; overflow: hidden; background: transparent;
      touch-action: none;
      -webkit-user-select: none; -ms-user-select: none; user-select:none;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    }
    #root { position: relative; width: 100vw; height: 100vh; background: transparent; }
    video#input_video { position: absolute; left: 0; top: 0; width: 100%; height: 100%; object-fit: cover; transform: scaleX(-1); }
    canvas#three-canvas { position: absolute; left: 0; top: 0; width: 100%; height: 100%; pointer-events: none; }
    #overlayGui { position: absolute; z-index: 10; left: 8px; top: 8px; color: white; font-family: monospace; font-size: 12px; }
    #debugStats { position: absolute; z-index: 11; right: 12px; top: 12px; background: rgba(0,0,0,0.7); color: #0f0; padding: 8px; font-family: monospace; font-size: 11px; border-radius: 4px; display: $debugMode ? 'block' : 'none'; }
  </style>
</head>
<body>
  <div id="root">
    <video id="input_video" autoplay playsinline muted></video>
    <canvas id="three-canvas"></canvas>
    <div id="overlayGui"></div>
    <div id="debugStats"></div>
  </div>

  <script>
  (function () {
    const video = document.getElementById('input_video');
    const canvas = document.getElementById('three-canvas');
    const overlayGui = document.getElementById('overlayGui');
    const debugStats = document.getElementById('debugStats');
    
    const DEBUG = $debugMode;
    const EARRINGS_MODEL_URL = '$earringsUrl';
    const NECKLACE_MODEL_URL = '$necklaceUrl';

    // MediaPipe landmark indices
    const LEFT_EAR_IDX = 234;
    const RIGHT_EAR_IDX = 454;
    const CHIN_IDX = 152;
    const NECK_LEFT_IDX = 175;
    const NECK_RIGHT_IDX = 398;

    // Smoothing constants (temporal filtering)
    const ALPHA = 0.7; // smooth factor: higher = more smoothing
    const EAR_DISTANCE_SMOOTHING = 0.85;
    const POSITION_SMOOTHING = 0.78;
    const SCALE_SMOOTHING = 0.82;

    let videoWidth = 640, videoHeight = 480;
    let renderer, scene, camera;
    let earringLeftGroup = null, earringRightGroup = null, necklaceGroup = null;
    let earringModel = null, necklaceModel = null;
    let modelsLoaded = { earrings: false, necklace: false };
    let visible = { earrings: false, necklace: false };

    // Smoothing state
    let smoothState = {
      leftEarPos: null,
      rightEarPos: null,
      neckPos: null,
      earDistance: 0,
      scale: { earring: 1, necklace: 1 }
    };

    // Debug stats
    let frameCount = 0;
    let lastFpsTime = Date.now();
    let fps = 0;

    function initThree() {
      renderer = new THREE.WebGLRenderer({ canvas: canvas, alpha: true, antialias: true });
      resizeThree();
      scene = new THREE.Scene();

      camera = new THREE.OrthographicCamera(
        -videoWidth / 2, videoWidth / 2, videoHeight / 2, -videoHeight / 2, 0.1, 2000
      );
      camera.position.set(0, 0, 1000);
      scene.add(camera);

      // Improved lighting for better 3D appearance
      const ambLight = new THREE.AmbientLight(0xffffff, 0.75);
      const hemiLight = new THREE.HemisphereLight(0xffffff, 0x333333, 0.9);
      const dirLight = new THREE.DirectionalLight(0xffffff, 0.7);
      dirLight.position.set(100, 200, 150);
      dirLight.castShadow = true;
      
      scene.add(ambLight);
      scene.add(hemiLight);
      scene.add(dirLight);

      earringLeftGroup = new THREE.Group();
      earringRightGroup = new THREE.Group();
      necklaceGroup = new THREE.Group();

      scene.add(earringLeftGroup);
      scene.add(earringRightGroup);
      scene.add(necklaceGroup);
    }

    function resizeThree() {
      if (!renderer) return;
      const dpr = window.devicePixelRatio || 1;
      const w = video.clientWidth || window.innerWidth;
      const h = video.clientHeight || window.innerHeight;
      renderer.setPixelRatio(dpr);
      renderer.setSize(w, h, false);
      canvas.style.width = w + 'px';
      canvas.style.height = h + 'px';
      
      if (camera) {
        videoWidth = w;
        videoHeight = h;
        camera.left = -videoWidth / 2;
        camera.right = videoWidth / 2;
        camera.top = videoHeight / 2;
        camera.bottom = -videoHeight / 2;
        camera.updateProjectionMatrix();
      }
    }

    window.addEventListener('resize', () => resizeThree());

    function lmToPixel(lm) {
      // MediaPipe: (0,0) top-left, (1,1) bottom-right
      // Orthographic camera: (0,0) center
      const x = (lm.x - 0.5) * videoWidth;
      const y = -(lm.y - 0.5) * videoHeight;
      const z = (lm.z || 0) * videoWidth;
      return new THREE.Vector3(x, y, z);
    }

    // Temporal smoothing: exponential moving average
    function smoothVector(current, previous, alpha) {
      if (!previous) return current;
      return new THREE.Vector3(
        previous.x + alpha * (current.x - previous.x),
        previous.y + alpha * (current.y - previous.y),
        previous.z + alpha * (current.z - previous.z)
      );
    }

    function smoothScalar(current, previous, alpha) {
      if (previous === null || previous === undefined) return current;
      return previous + alpha * (current - previous);
    }

    const gltfLoader = new THREE.GLTFLoader();

    function loadModel(url) {
      return new Promise((resolve, reject) => {
        gltfLoader.load(
          url,
          (gltf) => resolve(gltf.scene),
          undefined,
          (err) => reject(err)
        );
      });
    }

    async function ensureModels() {
      try {
        if (!modelsLoaded.earrings && EARRINGS_MODEL_URL) {
          const m = await loadModel(EARRINGS_MODEL_URL);
          earringModel = m;
          earringModel.visible = false;
          earringModel.traverse((c) => { 
            if (c.isMesh) c.castShadow = true;
          });
          earringLeftGroup.add(earringModel.clone());
          earringRightGroup.add(earringModel.clone());
          modelsLoaded.earrings = true;
          if (DEBUG) console.log('Earrings model loaded');
        }
      } catch (e) {
        console.warn('Failed loading earrings model:', e);
      }
      try {
        if (!modelsLoaded.necklace && NECKLACE_MODEL_URL) {
          const m = await loadModel(NECKLACE_MODEL_URL);
          necklaceModel = m;
          necklaceModel.visible = false;
          necklaceModel.traverse((c) => { 
            if (c.isMesh) c.castShadow = true;
          });
          necklaceGroup.add(necklaceModel.clone());
          modelsLoaded.necklace = true;
          if (DEBUG) console.log('Necklace model loaded');
        }
      } catch (e) {
        console.warn('Failed loading necklace model:', e);
      }
    }

    function updateAnchors(landmarks) {
      if (!landmarks) return;

      const leftEar = landmarks[LEFT_EAR_IDX];
      const rightEar = landmarks[RIGHT_EAR_IDX];
      const chin = landmarks[CHIN_IDX];
      const neckL = landmarks[NECK_LEFT_IDX];
      const neckR = landmarks[NECK_RIGHT_IDX];

      if (leftEar && rightEar) {
        const pLeft = lmToPixel(leftEar);
        const pRight = lmToPixel(rightEar);

        // Smooth ear positions
        smoothState.leftEarPos = smoothVector(pLeft, smoothState.leftEarPos, POSITION_SMOOTHING);
        smoothState.rightEarPos = smoothVector(pRight, smoothState.rightEarPos, POSITION_SMOOTHING);

        const earDist = smoothState.leftEarPos.distanceTo(smoothState.rightEarPos);
        smoothState.earDistance = smoothScalar(earDist, smoothState.earDistance, EAR_DISTANCE_SMOOTHING);

        const baseScale = smoothState.earDistance / 120.0; // tune divisor for model size
        smoothState.scale.earring = smoothScalar(baseScale, smoothState.scale.earring, SCALE_SMOOTHING);

        if (earringLeftGroup) {
          earringLeftGroup.visible = visible.earrings && modelsLoaded.earrings;
          earringLeftGroup.position.copy(smoothState.leftEarPos);
          earringLeftGroup.scale.setScalar(smoothState.scale.earring);
          
          // Compute yaw from ear vector
          const dx = smoothState.rightEarPos.x - smoothState.leftEarPos.x;
          const dy = smoothState.rightEarPos.y - smoothState.leftEarPos.y;
          const yaw = Math.atan2(dy, dx);
          earringLeftGroup.rotation.z = yaw;
        }

        if (earringRightGroup) {
          earringRightGroup.visible = visible.earrings && modelsLoaded.earrings;
          earringRightGroup.position.copy(smoothState.rightEarPos);
          earringRightGroup.scale.setScalar(smoothState.scale.earring);
          
          const dx = smoothState.rightEarPos.x - smoothState.leftEarPos.x;
          const dy = smoothState.rightEarPos.y - smoothState.leftEarPos.y;
          const yaw = Math.atan2(dy, dx);
          earringRightGroup.rotation.z = yaw;
        }
      }

      if (chin && neckL && neckR && necklaceGroup) {
        const pChin = lmToPixel(chin);
        const pNeckL = lmToPixel(neckL);
        const pNeckR = lmToPixel(neckR);

        const neckCenter = new THREE.Vector3(
          (pNeckL.x + pNeckR.x) / 2 + (pChin.x - (pNeckL.x + pNeckR.x) / 2) * 0.15,
          (pNeckL.y + pNeckR.y) / 2 + (pChin.y - (pNeckL.y + pNeckR.y) / 2) * 0.35,
          (pNeckL.z + pNeckR.z) / 2
        );

        smoothState.neckPos = smoothVector(neckCenter, smoothState.neckPos, POSITION_SMOOTHING);

        const neckDist = pNeckL.distanceTo(pNeckR);
        const scale = neckDist / 90.0;
        smoothState.scale.necklace = smoothScalar(scale, smoothState.scale.necklace, SCALE_SMOOTHING);

        necklaceGroup.visible = visible.necklace && modelsLoaded.necklace;
        necklaceGroup.position.copy(smoothState.neckPos);
        necklaceGroup.scale.setScalar(smoothState.scale.necklace);
        necklaceGroup.rotation.set(0, 0, 0);
      }
    }

    function animate() {
      requestAnimationFrame(animate);
      
      if (DEBUG) {
        frameCount++;
        const now = Date.now();
        if (now - lastFpsTime > 1000) {
          fps = frameCount;
          frameCount = 0;
          lastFpsTime = now;
        }
        debugStats.innerText = 'FPS: ' + fps + '\\nEarrings: ' + (visible.earrings ? 'ON' : 'OFF') + '\\nNecklace: ' + (visible.necklace ? 'ON' : 'OFF');
      }

      if (renderer && scene && camera) {
        renderer.render(scene, camera);
      }
    }

    const faceMesh = new FaceMesh.FaceMesh({
      locateFile: (file) => {
        return 'https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh@0.4/' + file;
      }
    });
    faceMesh.setOptions({
      maxNumFaces: 1,
      refineLandmarks: true,
      minDetectionConfidence: 0.6,
      minTrackingConfidence: 0.6
    });

    faceMesh.onResults((results) => {
      if (!results.multiFaceLandmarks || results.multiFaceLandmarks.length === 0) {
        if (earringLeftGroup) earringLeftGroup.visible = false;
        if (earringRightGroup) earringRightGroup.visible = false;
        if (necklaceGroup) necklaceGroup.visible = false;
        return;
      }
      const landmarks = results.multiFaceLandmarks[0];
      updateAnchors(landmarks);
    });

    function startCamera() {
      const constraints = {
        audio: false,
        video: {
          width: { ideal: 1280 },
          height: { ideal: 720 },
          facingMode: 'user'
        }
      };
      navigator.mediaDevices.getUserMedia(constraints)
        .then(function (stream) {
          video.srcObject = stream;
          video.onloadedmetadata = () => {
            video.play();
            videoWidth = video.clientWidth || video.videoWidth || window.innerWidth;
            videoHeight = video.clientHeight || video.videoHeight || window.innerHeight;
            resizeThree();
            ensureModels();

            const cameraUtils = window.Camera;
            if (cameraUtils && cameraUtils.Camera) {
              const cam = new cameraUtils.Camera(video, {
                onFrame: async () => {
                  await faceMesh.send({ image: video });
                },
                width: videoWidth,
                height: videoHeight
              });
              cam.start();
            } else {
              setInterval(() => { faceMesh.send({ image: video }); }, 33);
            }
          };
        })
        .catch(function (err) {
          console.error('getUserMedia error:', err);
          overlayGui.innerText = '❌ Camera permission needed.';
        });
    }

    window.addEventListener('message', (ev) => {
      try {
        const data = ev.data || {};
        if (data && data.type === 'toggle' && data.item) {
          const item = data.item;
          if (item === 'earrings') {
            visible.earrings = !visible.earrings;
            if (visible.earrings && !modelsLoaded.earrings) ensureModels();
          } else if (item === 'necklace') {
            visible.necklace = !visible.necklace;
            if (visible.necklace && !modelsLoaded.necklace) ensureModels();
          }
          overlayGui.innerText = '✓ ' + (item === 'earrings' ? 'Earrings: ' : 'Necklace: ') + (visible[item] ? 'ON' : 'OFF');
          setTimeout(() => { overlayGui.innerText = ''; }, 1000);
        }
      } catch (e) {
        console.warn('message handler error', e);
      }
    });

    function init() {
      initThree();
      animate();
      startCamera();
      overlayGui.innerText = 'Loading AR...';
      setTimeout(() => { overlayGui.innerText = ''; }, 600);
    }

    init();

    // Public API for debugging
    window.toggleItem = function(item) {
      visible[item] = !visible[item];
    };

  })();
  </script>
</body>
</html>
''';
  }

  void _postMessageToIframe(Map<String, dynamic> message) {
    final String iframeId = '$_iframeIdPrefix$_viewId';
    final html.Element? el = html.document.getElementById(iframeId);
    if (el is html.IFrameElement) {
      el.contentWindow?.postMessage(message, '*');
    } else {
      html.document.querySelectorAll('iframe').forEach((frame) {
        if ((frame as html.IFrameElement).id.startsWith(_iframeIdPrefix)) {
          (frame as html.IFrameElement)
              .contentWindow
              ?.postMessage(message, '*');
        }
      });
    }
  }

  void _toggleEarrings() {
    _postMessageToIframe({'type': 'toggle', 'item': 'earrings'});
    setState(() => _isModelLoaded = true);
  }

  void _toggleNecklace() {
    _postMessageToIframe({'type': 'toggle', 'item': 'necklace'});
    setState(() => _isModelLoaded = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.expand(
          child: HtmlElementView(viewType: _viewId),
        ),

        // Control overlay buttons
        Positioned(
          right: 20,
          bottom: 140,
          child: Column(
            children: [
              FloatingActionButton.extended(
                onPressed: _toggleEarrings,
                label: const Text('Try Earrings'),
                icon: const Icon(Icons.diamond),
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                onPressed: _toggleNecklace,
                label: const Text('Try Necklace'),
                icon: const Icon(Icons.link),
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
              ),
            ],
          ),
        ),

        // Info text
        Positioned(
          left: 12,
          bottom: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Allow camera access for AR',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),

        // Back button
        Positioned(
          top: 16,
          left: 16,
          child: FloatingActionButton(
            mini: true,
            onPressed: () => Navigator.pop(context),
            backgroundColor: Colors.black54,
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
