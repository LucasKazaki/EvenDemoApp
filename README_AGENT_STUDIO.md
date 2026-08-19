# Agent Studio Even G1 Companion

This branch converts the official Even G1 demo into a secure companion for a self-hosted Agent Studio orchestrator.

## Implemented

- Existing dual-BLE connection to the left and right G1 arms.
- Existing G1 TouchBar voice activation.
- Existing LC3-to-PCM conversion and Apple speech recognition path.
- G1 text pagination and response display.
- Agent Studio pairing settings in the phone application.
- Device token storage through platform secure storage.
- Automatic device UUID generation.
- `POST /api/v1/messages` client with idempotency.
- Automatic project and thread routing request metadata.
- `GET /api/v1/health` connection test.
- Replayable WebSocket event client at `/api/v1/events`.
- Exponential event-stream reconnection.
- Glanceable G1 notifications for task completion, failure, blockers, alerts, and approval requests.
- Rate limiting so background events do not constantly replace the G1 display.
- No provider API keys in the mobile source.
- Flutter analysis and test workflow for pull requests.

## Architecture

```text
Even G1 left and right arms
            |
        dual BLE
            |
  Flutter iPhone companion
  speech recognition, secure token,
  REST requests, WebSocket events
            |
        HTTPS / WSS
            |
    Agent Studio gateway
  routing, memory, delegation,
  approvals, tasks, model selection
            |
 local and cloud worker models
```

The phone does not select Claude, Codex, OpenAI, Ollama, or another provider. Agent Studio owns that decision.

## Backend contract

Implement the endpoints described in [`docs/AGENT_STUDIO_API.md`](docs/AGENT_STUDIO_API.md):

- `GET /api/v1/health`
- `POST /api/v1/messages`
- WebSocket `/api/v1/events`

## iPhone setup

A physical G1 requires a real iPhone and a Mac running Xcode.

1. Install the current stable Flutter SDK and Xcode.
2. Clone the repository and check out `agent/agent-studio-g1-client`.
3. Run:

   ```bash
   flutter pub get
   cd ios
   pod install
   cd ..
   open ios/Runner.xcworkspace
   ```

4. In Xcode, select the `Runner` target.
5. Under Signing and Capabilities, choose your Apple development team.
6. Change the bundle identifier from the example identifier to one owned by your team, such as `com.lucastao.agentstudiog1`.
7. Confirm that Bluetooth and Keychain entitlements are present.
8. Connect the iPhone, trust the computer, and run the `Runner` target.
9. Grant Bluetooth and Speech Recognition permission when prompted.
10. Connect both G1 arms from the application home screen.

The repository includes the Keychain entitlement files and references them from the Flutter Xcode configurations. Xcode may still update signing metadata when you select your own development team.

## Pair Agent Studio

1. Open the menu in the phone application.
2. Select **Agent Studio**.
3. Enter a private HTTPS base URL.
4. Enter a device-scoped token issued by Agent Studio.
5. Optionally enter a default project ID.
6. Select **Save and test**.

The device token is stored in secure platform storage. Do not place the token in source code, screenshots, GitHub Actions variables visible to forks, or G1 display content.

For development, the same values can be supplied with Dart defines:

```bash
flutter run \
  --dart-define=AGENT_STUDIO_BASE_URL=https://agent-studio.example.ts.net \
  --dart-define=AGENT_STUDIO_DEVICE_TOKEN=replace-with-a-paired-device-token \
  --dart-define=AGENT_STUDIO_PROJECT_ID=optional-project-id
```

Do not commit the command or shell history when it contains a real token.

## Use the G1

1. Connect both glasses arms.
2. Press and hold the left TouchBar.
3. Speak for up to 30 seconds.
4. Release the TouchBar.
5. The iPhone transcribes the G1 microphone audio.
6. The transcript is sent to Agent Studio.
7. Agent Studio routes the request, responds immediately, and may launch background work.
8. The concise response appears on the G1.
9. Relevant background events can appear later as short G1 status pages.

The existing G1 protocol supports manual page navigation and automatic paging for longer responses.

## Expected Agent Studio behavior

The mobile client requests automatic routing. The backend should decide whether to:

- Continue an existing thread.
- Fork an existing thread.
- Create a new thread.
- Create a new project proposal.
- Ask the user when routing confidence is insufficient.

The backend should return a concise display response immediately and place heavy work into a durable task system.

## Security model

The G1 display is not treated as a high-assurance approval surface. It may show that approval is required, but purchases, messages, applications, releases, destructive changes, credential operations, and security changes should be confirmed on the authenticated phone or desktop UI.

See [`SECURITY.md`](SECURITY.md) for credential and token requirements.

## Current limitations

- The branch has not yet been tested against Lucas's physical G1 or a production Agent Studio gateway.
- The backend endpoints must be added to Agent Studio.
- APNs and Live Activities are not included yet.
- AirPods realtime conversation mode is not included yet.
- The app uses the existing Apple on-device speech-recognition path for G1 microphone audio.
- iOS may suspend ordinary background networking. The event stream reconnects when the app resumes, and production background alerts should later use APNs.
- High-risk approvals intentionally remain phone or desktop actions.

## Validation

Run:

```bash
dart format lib test
flutter analyze --no-fatal-infos
flutter test
```

Physical acceptance testing should include:

- Both G1 arms connecting after a cold launch.
- G1 microphone start and stop.
- Speech recognition after permissions are granted.
- Agent Studio health-check success and failure.
- Token rejection.
- Message idempotency after a network retry.
- Event replay after disconnecting and reconnecting.
- A task-completed event appearing on the G1.
- No event interrupting an active voice interaction.
- App recovery after iPhone lock, G1 disconnect, and home-PC restart.
