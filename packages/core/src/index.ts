import { EventEmitter } from "events"
import * as os from "os"

/**
 * 键盘事件数据
 */
export interface KeyEvent {
    /** 键码 */
    keyCode: number
    /** 修饰键状态 */
    modifierFlags: number
}

/**
 * 原生模块接口
 */
interface NativeModule {
    start(callback: (event: KeyEvent) => void): boolean
    stop(): boolean
}

/**
 * 键盘监听器接口
 */
export interface KeyListenerInterface extends EventEmitter {
    /**
     * 启动监听器
     * @returns 是否成功启动
     */
    start(): Promise<boolean>

    /**
     * 停止监听器
     * @returns 是否成功停止
     */
    stop(): boolean

    /**
     * 获取监听器当前状态
     * @returns 是否正在监听
     */
    isListening(): boolean
}

// 静态导入原生模块
let nativeModule: NativeModule | null = null;
if (os.platform() === "darwin") {
    try {
        nativeModule = require("./key_listener.node");
    } catch (error) {
        console.error("加载键盘监听器原生模块失败:", error);
    }
}

/**
 * 键盘监听器
 * 
 * 监听macOS系统上的键盘按键事件。
 * 当检测到按键时触发'keypress'事件。
 */
export class KeyListener extends EventEmitter implements KeyListenerInterface {
    private _isListening: boolean = false

    constructor() {
        super()

        if (os.platform() !== "darwin") {
            console.warn("警告: 键盘监听器仅在macOS上可用")
        }
    }

    /**
     * 启动监听器
     */
    async start(): Promise<boolean> {
        if (this._isListening) return true

        if (!nativeModule) {
            console.error("原生键盘监听器不可用")
            return false
        }

        try {
            const success = nativeModule.start((event: KeyEvent) => {
                this.emit("keypress", event)
            })

            this._isListening = success
            return success
        } catch (error) {
            console.error("启动键盘监听器时出错:", error)
            return false
        }
    }

    /**
     * 停止监听器
     */
    stop(): boolean {
        if (!this._isListening) return true

        if (nativeModule) {
            try {
                const success = nativeModule.stop()
                this._isListening = false
                return success
            } catch (error) {
                console.error("停止键盘监听器时出错:", error)
                this._isListening = false
                return false
            }
        }

        this._isListening = false
        return true
    }

    /**
     * 获取监听器当前状态
     */
    isListening(): boolean {
        return this._isListening
    }
}

export default KeyListener
