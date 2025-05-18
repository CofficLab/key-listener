# @coffic/key-listener

[![English](https://img.shields.io/badge/English-violet)](README.md)
[![简体中文](https://img.shields.io/badge/中文文档-gray)](README-zh.md)
[![DEV](https://img.shields.io/badge/DEV-gray)](README-dev.md)
[![NPM](https://img.shields.io/badge/NPM-orange)](https://www.npmjs.com/package/@coffic/key-listener)
![NPM Downloads](https://img.shields.io/npm/dm/%40coffic%2Fkey-listener)
![NPM Version](https://img.shields.io/npm/v/%40coffic%2Fkey-listener)
[![Coffic](https://img.shields.io/badge/Coffic-green)](https://coffic.cn)
[![Maintainer](https://img.shields.io/badge/Maintainer-blue)](https://github.com/nookery)
![GitHub License](https://img.shields.io/github/license/cofficlab/key-listner)


A global keyboard event listener for macOS.

## Features

- Listen to all keyboard events on macOS (both in-app and system-wide)
- Support all types of keys (regular keys and modifier keys)
- Implemented with native modules for high performance and stability
- Simple event interface for easy integration
- Smart handling of repeated events, triggering only once per keypress

## Event Triggering Mechanism

This listener implements an intelligent event triggering mechanism:

1. **Single Trigger**: Each key triggers an event only once when pressed, regardless of whether it's a regular key or a modifier key (like Command, Shift, etc.)
2. **Hold Handling**: Holding down a key does not trigger repeated events
3. **Reset Mechanism**: A new event is only triggered after releasing and pressing the key again
4. **Unified Processing**: All types of keys are handled with the same logic, ensuring consistent and predictable behavior

This mechanism is particularly suitable for:
- Hotkey listening
- Global key triggers
- Keyboard statistics and analysis
- Keyboard event recording

## Installation

```bash
npm install @coffic/key-listener
```

## System Requirements

- **Operating System**: macOS only
- **Node.js**: >= 14.0.0
- **Build Tools**: Xcode Command Line Tools (for native module compilation)

## Basic Usage

```typescript
import { KeyListener } from '@coffic/key-listener';

// Create listener instance
const listener = new KeyListener();

// Listen for keyboard events
listener.on('keypress', (event) => {
  console.log('Key event:', {
    keyCode: event.keyCode  // Key code
  });
});

// Start the listener (returns Promise)
listener.start().then(success => {
  if (success) {
    console.log('Listener started');
  } else {
    console.error('Failed to start listener');
  }
});

// ... Other application logic ...

// Stop listening (when no longer needed)
listener.stop();
```

## API Reference

### `KeyListener` Class

#### Constructor

```typescript
new KeyListener()
```

Creates a new keyboard event listener instance.

#### Methods

##### `start(): Promise<boolean>`

Starts the listener. Returns a Promise that resolves to a boolean indicating success.

##### `stop(): boolean`

Stops the listener. Returns a boolean indicating success.

##### `isListening(): boolean`

Gets the current state of the listener. Returns a boolean indicating if it's listening.

#### Events

##### `keypress`

Triggered when a key event is detected. The event object contains:

- `keyCode: number` - The key code of the pressed key

```typescript
listener.on('keypress', (event) => {
  // Handle key event
});
```

## Common Key Code Reference

- 54: Right Command key
- 55: Left Command key
- 56: Left Shift key
- 57: Caps Lock key
- 58: Left Option key
- 59: Left Control key
- 60: Right Shift key
- 61: Right Option key
- 62: Right Control key
- 63: Function key

For more key codes, please refer to example code or documentation.

## Important Notes

1. **Platform Limitation**: This package only works on macOS and will not function on other platforms (though it won't cause errors).

2. **Permission Requirements**: Your application needs Accessibility permission to use this listener. macOS will prompt users to grant permission on first use.

3. **Application Packaging**: When packaging your application with Electron or other tools, ensure proper inclusion of native module files.

4. **Event Handling**: 
   - Each key triggers an event only once when pressed
   - Holding a key won't trigger repeated events
   - New events require releasing and pressing the key again
   - This behavior applies to all key types, including modifier keys

## Troubleshooting

### Listener Won't Start

- Check if you're running on macOS
- Ensure Accessibility permission is granted
- Check console for error messages

### Compilation Errors

If you encounter compilation errors during installation:

- Ensure Xcode Command Line Tools are installed: `xcode-select --install`
- Verify Node.js version compatibility
- Try rebuilding native modules with `npm rebuild`

## License

MIT

## Contributing

Issues and Pull Requests are welcome.
