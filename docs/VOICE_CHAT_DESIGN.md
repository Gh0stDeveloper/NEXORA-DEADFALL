# Voice chat design — investigation only

This document records the proposed global Squad voice architecture. Phase 8 does not ship voice transport yet.

## Product behavior

Voice is squad-global, not proximity-based. A player can hear the other squad members regardless of world distance. Initial controls should include microphone enable/disable, push-to-talk or open-mic mode, per-player mute and voice volume.

## Recommended self-hosted architecture

1. Capture microphone input on the client.
2. Process small real-time frames (target: 20 ms).
3. Convert to mono voice PCM and apply voice preprocessing where available.
4. Encode with Opus in VoIP mode.
5. Send encoded voice datagrams through a dedicated unreliable network stream/channel, separate from movement/snapshots.
6. The dedicated server validates speaker/session membership and relays packets only to the other members of that room.
7. Clients place packets in a short jitter buffer, decode Opus, then feed PCM into an `AudioStreamGenerator` playback path.

No position or attenuation is applied because this is global team communication.

## Why not raw PCM

Godot microphone capture exposes raw floating-point PCM. Raw PCM is straightforward but far too expensive for mobile network voice compared with a speech codec. Opus should be integrated through a compiled GDExtension/native plugin rather than implementing codec work in GDScript.

## Transport isolation

Voice must not share the same ordered stream as player snapshots. Packet loss in voice is preferable to stalling gameplay. A dedicated ENet channel/stream or a separate UDP voice service keeps audio traffic isolated from authoritative gameplay traffic.

## Android

The Android build will need microphone permission and runtime handling. For acceptable open-speaker voice, the native layer should use the platform voice-communication capture path when possible and enable available acoustic echo cancellation, noise suppression and gain control. Device support must be detected instead of assumed.

## Alternative: WebRTC/service provider

WebRTC provides mature NAT traversal and media semantics, but Godot native platforms require the native WebRTC extension and a signaling/ICE/STUN/TURN design. A hosted voice SDK can reduce codec/NAT work but introduces a third-party dependency and operating cost.

For DEADFALL's current four-player dedicated-server model, the first implementation recommendation is a small Opus relay integrated with the existing VPS/session identity, then move to a dedicated voice service only if scale or NAT requirements justify it.

## Security and privacy requirements

- Never trust a client-provided room membership claim; bind voice identity to the authenticated gameplay session/token.
- Rate-limit voice packets and enforce maximum encoded packet size.
- Do not record/store voice by default.
- Provide mute/block controls before public beta.
- Clearly request microphone permission only when voice is enabled.
- Add abuse/reporting hooks before public matchmaking.
