import { EventEmitter } from "events"
import * as os from "os"
import * as path from "path"

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

// 加载原生模块
function loadNativeModule() {
    try {
        if (os.platform() !== "darwin") {
            console.warn("警告: 键盘监听器仅在macOS上可用")
            return null
        }

        const possiblePaths = [
            path.join(__dirname, "..", "dist", "key_listener.node"),
            path.join(process.cwd(), "dist", "key_listener.node"),
            path.join(__dirname, "dist", "key_listener.node"),
        ]

        for (const modulePath of possiblePaths) {
            try {
                if (require("fs").existsSync(modulePath)) {
                    return require(modulePath)
                }
            } catch (err) {
                console.error("加载模块失败:", modulePath, err)
            }
        }

        console.error("找不到键盘监听器原生模块")
        return null
    } catch (error) {
        console.error("加载键盘监听器原生模块失败:", error)
        return null
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
    private _nativeModule: any | null

    constructor() {
        super()

        if (os.platform() !== "darwin") {
            console.warn("警告: 键盘监听器仅在macOS上可用")
            this._nativeModule = null
        } else {
            this._nativeModule = loadNativeModule()
        }
    }

    /**
     * 启动监听器
     */
    async start(): Promise<boolean> {
        if (this._isListening) return true

        if (!this._nativeModule) {
            console.error("原生键盘监听器不可用")
            return false
        }

        try {
            const success = this._nativeModule.start((event: KeyEvent) => {
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

        if (this._nativeModule) {
            try {
                const success = this._nativeModule.stop()
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
