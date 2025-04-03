# @coffic/key-listener

macOS系统全局键盘事件监听器。

## 功能介绍

- 监听 macOS 系统上的所有键盘事件（包括应用内和应用外）
- 支持所有类型的按键，包括普通键和修饰键（Command、Option、Control、Shift等）
- 使用原生模块实现，性能高效稳定
- 提供简单的事件接口，易于集成
- 智能处理重复事件，避免重复触发

## 安装

```bash
npm install @coffic/key-listener
```

## 系统要求

- **操作系统**: 仅支持 macOS 系统
- **Node.js**: >= 14.0.0
- **构建工具**: Xcode命令行工具（用于编译原生模块）

## 基本用法

```typescript
import { KeyListener } from '@coffic/key-listener';

// 创建监听器实例
const listener = new KeyListener();

// 监听键盘事件
listener.on('keypress', (event) => {
  console.log('按键事件:', {
    keyCode: event.keyCode,      // 键码
    modifierFlags: event.modifierFlags  // 修饰键状态
  });
});

// 启动监听器（返回Promise）
listener.start().then(success => {
  if (success) {
    console.log('监听器已启动');
  } else {
    console.error('监听器启动失败');
  }
});

// ... 应用其他逻辑 ...

// 停止监听（不再需要时）
listener.stop();
```

## API参考

### `KeyListener` 类

#### 构造函数

```typescript
new KeyListener()
```

创建一个新的键盘事件监听器实例。

#### 方法

##### `start(): Promise<boolean>`

启动监听器。返回一个Promise，解析为布尔值表示是否成功启动。

##### `stop(): boolean`

停止监听器。返回布尔值表示是否成功停止。

##### `isListening(): boolean`

获取监听器的当前状态。返回布尔值表示是否正在监听。

#### 事件

##### `keypress`

当检测到按键事件时触发。事件对象包含以下属性：

- `keyCode: number` - 按键的键码
- `modifierFlags: number` - 修饰键状态的位掩码

```typescript
listener.on('keypress', (event) => {
  // 处理按键事件
});
```

## 常见键码参考

- 54: 右Command键
- 55: 左Command键
- 56: 左Shift键
- 57: Caps Lock键
- 58: 左Option键
- 59: 左Control键
- 60: 右Shift键
- 61: 右Option键
- 62: 右Control键
- 63: Function键

更多键码请参考示例代码或文档。

## 注意事项

1. **平台限制**: 此包仅在macOS系统上可用，在其他平台上将不起作用但不会导致错误。

2. **权限要求**: 使用此监听器时，您的应用需要辅助功能（Accessibility）权限。首次使用时，macOS会提示用户授予权限。

3. **应用打包**: 在使用Electron或其他工具打包应用时，请确保正确包含原生模块文件。

4. **事件处理**: 监听器会智能处理重复事件，确保每次按键只触发一次事件。对于修饰键，只在按下时触发事件，释放时不会触发。

## 故障排除

### 监听器无法启动

- 检查您是否在macOS系统上运行
- 确保已授予应用辅助功能权限
- 检查控制台是否有错误信息

### 编译错误

如果在安装过程中遇到编译错误：

- 确保已安装Xcode命令行工具：`xcode-select --install`
- 确保Node.js版本兼容
- 尝试使用`npm rebuild`重建原生模块

## 许可证

MIT

## 贡献

欢迎提交Issue和Pull Request。
