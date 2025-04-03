const { app, BrowserWindow } = require('electron');
const { KeyListener } = require('@coffic/key-listener');

let mainWindow = null;
let keyListener = null;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
    },
  });

  mainWindow.loadFile('index.html');

  console.log('正在初始化键盘监听器...');

  // 创建并启动键盘监听器
  keyListener = new KeyListener();
  keyListener.on('keypress', (event) => {
    // 在控制台输出事件数据
    console.log('接收到按键事件:', {
      event: event,
      timestamp: new Date().toISOString(),
      isApplicationActive:
        mainWindow && !mainWindow.isDestroyed() && mainWindow.isFocused(),
    });
  });

  keyListener.start().then((success) => {
    console.log('键盘监听器状态:', success ? '启动成功' : '启动失败');
  });
}

app.whenReady().then(() => {
  console.log('应用程序准备就绪，创建窗口...');
  createWindow();
});

app.on('window-all-closed', () => {
  console.log('所有窗口已关闭');
  if (process.platform !== 'darwin') {
    app.quit();
  }
  if (keyListener) {
    console.log('停止键盘监听器');
    keyListener.stop();
  }
});

app.on('activate', () => {
  console.log('应用程序被激活');
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
