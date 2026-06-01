# CoreML and Subtitle Recognition Performance Roadmap

Date: 2026-06-01

## Current Baseline

The current shipping recognizer path is sherpa-onnx Paraformer Chinese int8 on CPU, with Apple Speech as the final fallback. The latest measured real-device report from the 664.2 second test file used:

- Thread count: 6
- Long-audio window: 35 seconds
- Windows: 19
- Subtitle windows: 19
- Average window recognition time: 1.97 seconds
- Slowest window recognition time: 2.54 seconds
- Total recognition time: 40.00 seconds
- Real-time factor: about 0.060, or about 16.6x realtime

This is already fast enough for normal use, so CoreML must prove a real device benefit before it becomes a default.

## M25: CoreML Provider Experiment

Goal: make CoreML testable on real devices without risking the working CPU path.

Implementation scope:

- Keep CPU as the default recognition provider.
- Add Debug setting `本地识别后端` with `CPU` and `CoreML(实验)`.
- Pass the selected provider into sherpa-onnx offline recognizer config.
- Include provider in the cached recognizer key, so switching provider rebuilds the engine.
- Log provider and engine load time.
- If CoreML throws during recognition, retry sherpa-onnx once with CPU before falling back to Apple Speech.

Acceptance:

- Existing CPU recognition behavior and defaults are unchanged.
- Debug logs clearly show selected provider, thread count, window length, per-window timing, and final total timing.
- CoreML failure does not leave the user without subtitles if CPU or Apple Speech can still complete.
- CoreML experiment conclusions must not rely on whether the recognizer throws. A valid conclusion needs runtime diagnostics showing whether CoreML received useful graph partitions, plus repeated timing data.

## M26: Provider Options and Runtime Cache Investigation

Goal: determine whether ONNX Runtime CoreML EP can avoid excessive first-run compile overhead and use useful CoreML subgraphs.

Investigation tasks:

- Check whether the sherpa-onnx C API exposes provider option strings for CoreML in the iOS wrapper version currently bundled.
- If not exposed, inspect whether updating the wrapper or adding a minimal provider-options bridge is justified.
- Test CoreML first run and second run separately because CoreML compilation/cache can dominate the first run.
- Record engine load time separately from decode and per-window recognition time.
- Compare CPU vs CoreML with the same file, thread count, and window length.
- Treat `model.int8.onnx` plus dynamic-shape Paraformer as a likely poor CoreML EP fit until diagnostics prove otherwise.

Possible provider options to evaluate only if the wrapper supports them:

- CoreML cache directory, if exposed.
- static-shape or shape-related options, if exposed.
- ANE-only or CPU/GPU/ANE device preference, if exposed.

Stop condition:

- If CoreML either fails to initialize, produces empty subtitles, shows little/no useful CoreML graph partitioning, or does not improve repeat-run total time by at least 15 percent on the baseline file, keep it experimental and do not spend time converting models yet.
- Observed on the 664.2 second baseline file: CoreML loaded in 13.35 seconds, decoded 19 windows in about 2.02 seconds total, and produced 0 subtitle segments. This should be treated as a failed CoreML EP experiment for the current int8 model unless future diagnostics prove a different graph export behaves correctly.

## M27: Window Shape and Scheduling Tuning

Goal: reduce overhead without making subtitle timing too coarse.

Tasks:

- Compare 25, 35, and 45 second windows using the best CPU thread setting and CoreML if it is stable.
- Consider a 60 second debug-only window only if 45 seconds is clearly faster and subtitle timing remains acceptable.
- Measure subtitle count and content drift, not just total time.
- Keep the UI progress copy user-facing; debug logs may keep window-level technical detail.

Acceptance:

- A new default window length is selected only after at least two repeated runs per candidate.
- Subtitle count and obvious text quality do not regress versus the current baseline.

## M28: ONNX Graph Compatibility Analysis

Goal: decide whether CoreML EP has enough supported graph coverage to matter.

Tasks:

- Inspect Paraformer ONNX ops and dynamic-shape behavior.
- Enable any available ONNX Runtime/CoreML diagnostics in a development build.
- Identify whether unsupported ops force most of the model back to CPU.
- Document observed failure modes, including runtime fallback, compile errors, or no speedup.

Stop condition:

- If only a small part of the model runs through CoreML, stop CoreML EP optimization and keep CPU as the product path.

## M29: Native CoreML Conversion POC

Goal: only if M25-M28 show CoreML potential but ONNX Runtime EP is blocked by wrapper/runtime limits.

Tasks:

- Attempt a separate conversion POC of the same model family to CoreML.
- Keep the POC outside the app target until it proves it can load and run on device.
- Compare output text quality against the current sherpa-onnx CPU path.
- Estimate app size, conversion maintenance cost, and model update friction.

Risk:

- This is a larger runtime change. It should not replace the stable sherpa-onnx path unless it is meaningfully faster and equally reliable.

## M30: Product Default Decision

Goal: pick the default based on measured user value, not theoretical acceleration.

Decision criteria:

- Speed: at least 15 percent faster total repeat-run time than CPU on the baseline file.
- Reliability: no crashes, no incomplete subtitles, and clear fallback behavior.
- Quality: no obvious subtitle count or text quality regression.
- UX: device remains responsive and does not heat aggressively during 10 to 20 minute files.
- Maintainability: model assets and build scripts remain understandable and cloud-buildable.

Likely outcomes:

- If CoreML is unstable or not faster, keep CPU as default and leave CoreML in Debug as an experimental profiler switch.
- If CoreML is faster but first-run compile cost is high, keep CPU default and document CoreML as a repeated-run experiment.
- If CoreML is consistently faster and stable, promote it behind a non-debug setting only after repeated real-device validation.
