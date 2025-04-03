const { app, BrowserWindow, ipcMain } = require('electron');
const { KeyListener } = require('@coffic/key-listener');

let mainWindow = null;
let keyListener = null;

// 键码映射表
const KeyCodeMap = {
  0: 'a',
  1: 's',
  2: 'd',
  3: 'f',
  4: 'h',
  5: 'g',
  6: 'z',
  7: 'x',
  8: 'c',
  9: 'v',
  11: 'b',
  12: 'q',
  13: 'w',
  14: 'e',
  15: 'r',
  16: 'y',
  17: 't',
  18: '1',
  19: '2',
  20: '3',
  21: '4',
  22: '6',
  23: '5',
  24: '=',
  25: '9',
  26: '7',
  27: '-',
  28: '8',
  29: '0',
  30: ']',
  31: 'o',
  32: 'u',
  33: '[',
  34: 'i',
  35: 'p',
  36: 'Return',
  37: 'l',
  38: 'j',
  39: "'",
  40: 'k',
  41: ';',
  42: '\\',
  43: ',',
  44: '/',
  45: 'n',
  46: 'm',
  47: '.',
  48: 'Tab',
  49: 'Space',
  50: '`',
  51: 'Delete',
  53: 'Escape',
  54: 'Right Command',
  55: 'Left Command',
  56: 'Left Shift',
  57: 'Caps Lock',
  58: 'Left Option',
  59: 'Left Control',
  60: 'Right Shift',
  61: 'Right Option',
  62: 'Right Control',
  63: 'Function',
  64: 'F17',
  72: 'Volume Up',
  73: 'Volume Down',
  74: 'Mute',
  79: 'F18',
  80: 'F19',
  90: 'F20',
  96: 'F5',
  97: 'F6',
  98: 'F7',
  99: 'F3',
  100: 'F8',
  101: 'F9',
  103: 'F11',
  105: 'F13',
  106: 'F16',
  107: 'F14',
  109: 'F10',
  111: 'F12',
  113: 'F15',
  114: 'Help',
  115: 'Home',
  116: 'Page Up',
  117: 'Forward Delete',
  118: 'F4',
  119: 'End',
  120: 'F2',
  121: 'Page Down',
  122: 'F1',
  123: 'Left Arrow',
  124: 'Right Arrow',
  125: 'Down Arrow',
  126: 'Up Arrow',
};

// 设置全局错误处理
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('listener-status', {
      isListening: false,
      error: `未捕获的错误: ${error.message}`,
    });
  }
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send('listener-status', {
      isListening: false,
      error: `未处理的 Promise 拒绝: ${reason}`,
    });
  }
});

function createWindow() {
  try {
    mainWindow = new BrowserWindow({
      width: 800,
      height: 600,
      webPreferences: {
        nodeIntegration: true,
        contextIsolation: false,
      },
    });

    mainWindow.loadFile('index.html');
    // mainWindow.webContents.openDevTools()

    // 创建键盘监听器实例
    try {
      keyListener = new KeyListener();
      console.log('键盘监听器实例创建成功');
    } catch (error) {
      console.error('创建键盘监听器实例失败:', error);
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.webContents.send('listener-status', {
          isListening: false,
          error: `创建监听器失败: ${error.message}`,
        });
      }
      return;
    }

    // 监听键盘事件
    keyListener.on('keypress', (event) => {
      try {
        if (mainWindow && !mainWindow.isDestroyed()) {
          // 获取按键名称
          const keyName =
            KeyCodeMap[event.keyCode] || `Unknown Key (${event.keyCode})`;

          console.log('按键事件:', {
            keyCode: event.keyCode,
            keyName: keyName,
          });

          // 发送事件到渲染进程
          mainWindow.webContents.send('keypress', {
            keyCode: event.keyCode,
            keyName: keyName,
          });
        }
      } catch (error) {
        console.error('处理按键事件时出错:', error);
      }
    });

    // 启动监听器
    console.log('正在启动键盘监听器...');
    keyListener
      .start()
      .then((success) => {
        console.log('键盘监听器启动结果:', success);
        if (success) {
          console.log('键盘监听器启动成功');
          if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.webContents.send('listener-status', {
              isListening: true,
            });
          }
        } else {
          console.error('键盘监听器启动失败');
          if (mainWindow && !mainWindow.isDestroyed()) {
            mainWindow.webContents.send('listener-status', {
              isListening: false,
              error: '启动失败',
            });
          }
        }
      })
      .catch((error) => {
        console.error('启动键盘监听器时出错:', error);
        if (mainWindow && !mainWindow.isDestroyed()) {
          mainWindow.webContents.send('listener-status', {
            isListening: false,
            error: error.message,
          });
        }
      });
  } catch (error) {
    console.error('创建窗口时出错:', error);
  }
}

// 当 Electron 完成初始化时创建窗口
app
  .whenReady()
  .then(createWindow)
  .catch((error) => {
    console.error('初始化应用时出错:', error);
  });

// 当所有窗口关闭时退出应用
app.on('window-all-closed', () => {
  try {
    if (keyListener) {
      keyListener.stop();
    }
    if (process.platform !== 'darwin') {
      app.quit();
    }
  } catch (error) {
    console.error('关闭窗口时出错:', error);
  }
});

app.on('activate', () => {
  try {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  } catch (error) {
    console.error('激活应用时出错:', error);
  }
});

// 处理来自渲染进程的控制命令
ipcMain.on('control-listener', (event, command) => {
  try {
    if (!keyListener) {
      console.error('键盘监听器未初始化');
      event.reply('listener-status', {
        isListening: false,
        error: '监听器未初始化',
      });
      return;
    }

    switch (command) {
      case 'start':
        console.log('正在启动监听器...');
        keyListener
          .start()
          .then((success) => {
            console.log('启动监听器结果:', success);
            event.reply('listener-status', { isListening: success });
          })
          .catch((error) => {
            console.error('启动监听器失败:', error);
            event.reply('listener-status', {
              isListening: false,
              error: error.message,
            });
          });
        break;
      case 'stop':
        console.log('正在停止监听器...');
        try {
          const success = keyListener.stop();
          console.log('停止监听器结果:', success);
          event.reply('listener-status', { isListening: !success });
        } catch (error) {
          console.error('停止监听器失败:', error);
          event.reply('listener-status', {
            isListening: true,
            error: error.message,
          });
        }
        break;
    }
  } catch (error) {
    console.error('处理控制命令时出错:', error);
    event.reply('listener-status', {
      isListening: false,
      error: error.message,
    });
  }
});
