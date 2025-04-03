#import <napi.h>
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// 全局状态
struct {
    bool isListening;
    Napi::ThreadSafeFunction tsfn;
    id localMonitor;
    id globalMonitor;
    NSTimeInterval lastEventTime;
    NSUInteger lastModifierFlags;  // 记录上一次的修饰键状态
} state;

// 事件数据结构
struct KeyEventData {
    uint16_t keyCode;
    uint64_t modifierFlags;
};

// 检查特定修饰键是否被按下
bool isModifierKeyPressed(NSUInteger flags, NSUInteger mask) {
    return (flags & mask) == mask;
}

// 安全地处理事件回调
bool SafeHandleKeyEvent(NSEvent* event) {
    @try {
        if (!state.isListening || !state.tsfn) {
            return false;
        }

        // 判断是否是修饰键
        bool isModifierKey = (event.keyCode >= 54 && event.keyCode <= 63); // 修饰键的键码范围

        if (isModifierKey) {
            // 对于修饰键，只处理 FlagsChanged 事件
            if (event.type != NSEventTypeFlagsChanged) {
                return false;
            }

            // 获取当前修饰键的掩码
            NSUInteger modifierMask = 0;
            switch (event.keyCode) {
                case 54: // Right Command
                case 55: // Left Command
                    modifierMask = NSEventModifierFlagCommand;
                    break;
                case 56: // Left Shift
                case 60: // Right Shift
                    modifierMask = NSEventModifierFlagShift;
                    break;
                case 58: // Left Option
                case 61: // Right Option
                    modifierMask = NSEventModifierFlagOption;
                    break;
                case 59: // Left Control
                case 62: // Right Control
                    modifierMask = NSEventModifierFlagControl;
                    break;
                default:
                    return false;
            }

            // 检查修饰键是否刚被按下
            bool wasPressed = isModifierKeyPressed(state.lastModifierFlags, modifierMask);
            bool isPressed = isModifierKeyPressed(event.modifierFlags, modifierMask);

            // 更新状态
            state.lastModifierFlags = event.modifierFlags;

            // 只在修饰键刚被按下时触发事件
            if (!wasPressed && isPressed) {
                KeyEventData* data = new KeyEventData();
                data->keyCode = event.keyCode;
                data->modifierFlags = event.modifierFlags;
                
                state.tsfn.NonBlockingCall(data, [](Napi::Env env, Napi::Function jsCallback, KeyEventData* data) {
                    @autoreleasepool {
                        Napi::Object event = Napi::Object::New(env);
                        event.Set("keyCode", data->keyCode);
                        event.Set("modifierFlags", (double)data->modifierFlags);
                        jsCallback.Call({event});
                        delete data;
                    }
                });
                return true;
            }
            return false;
        } else {
            // 对于普通键，只处理 KeyDown 事件
            if (event.type != NSEventTypeKeyDown) {
                return false;
            }

            // 检查事件时间戳，防止重复事件
            NSTimeInterval currentTime = event.timestamp;
            if (currentTime - state.lastEventTime < 0.01) { // 10毫秒内的事件视为重复
                return false;
            }
            state.lastEventTime = currentTime;

            KeyEventData* data = new KeyEventData();
            data->keyCode = event.keyCode;
            data->modifierFlags = event.modifierFlags;
            
            state.tsfn.NonBlockingCall(data, [](Napi::Env env, Napi::Function jsCallback, KeyEventData* data) {
                @autoreleasepool {
                    Napi::Object event = Napi::Object::New(env);
                    event.Set("keyCode", data->keyCode);
                    event.Set("modifierFlags", (double)data->modifierFlags);
                    jsCallback.Call({event});
                    delete data;
                }
            });
            return true;
        }

    } @catch (NSException* exception) {
        NSLog(@"Error handling key event: %@", exception);
        return false;
    }
}

// 启动监听器
Napi::Value Start(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    
    if (info.Length() < 1 || !info[0].IsFunction()) {
        Napi::TypeError::New(env, "Function expected as first argument").ThrowAsJavaScriptException();
        return env.Undefined();
    }
    
    if (state.isListening) {
        return Napi::Boolean::New(env, true);
    }
    
    @try {
        Napi::Function callback = info[0].As<Napi::Function>();
        
        // 创建线程安全函数引用
        state.tsfn = Napi::ThreadSafeFunction::New(
            env,
            callback,
            "KeyListener",
            0,
            1,
            []( Napi::Env ) {
                state.isListening = false;
            }
        );
        
        // 初始化状态
        state.lastEventTime = 0;
        state.lastModifierFlags = 0;
        
        // 添加本地按键监听器
        state.localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskFlagsChanged)
            handler:^NSEvent *(NSEvent *event) {
                SafeHandleKeyEvent(event);
                return event;
            }];
        
        // 添加全局按键监听器
        state.globalMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskFlagsChanged)
            handler:^(NSEvent *event) {
                SafeHandleKeyEvent(event);
            }];
        
        if (!state.localMonitor || !state.globalMonitor) {
            NSLog(@"Failed to create monitors");
            if (state.localMonitor) {
                [NSEvent removeMonitor:state.localMonitor];
                state.localMonitor = nil;
            }
            if (state.globalMonitor) {
                [NSEvent removeMonitor:state.globalMonitor];
                state.globalMonitor = nil;
            }
            if (state.tsfn) {
                state.tsfn.Release();
            }
            Napi::Error::New(env, "Failed to create key monitors").ThrowAsJavaScriptException();
            return env.Undefined();
        }
        
        state.isListening = true;
        return Napi::Boolean::New(env, true);
        
    } @catch (NSException* exception) {
        NSLog(@"Error starting key listener: %@", exception);
        Napi::Error::New(env, [[exception description] UTF8String]).ThrowAsJavaScriptException();
        return env.Undefined();
    }
}

// 停止监听器
Napi::Value Stop(const Napi::CallbackInfo& info) {
    Napi::Env env = info.Env();
    
    if (!state.isListening) {
        return Napi::Boolean::New(env, true);
    }
    
    @try {
        // 移除事件监听器
        if (state.localMonitor) {
            [NSEvent removeMonitor:state.localMonitor];
            state.localMonitor = nil;
        }
        
        if (state.globalMonitor) {
            [NSEvent removeMonitor:state.globalMonitor];
            state.globalMonitor = nil;
        }
        
        // 释放线程安全函数
        if (state.tsfn) {
            state.tsfn.Release();
        }
        
        state.isListening = false;
        return Napi::Boolean::New(env, true);
        
    } @catch (NSException* exception) {
        NSLog(@"Error stopping key listener: %@", exception);
        Napi::Error::New(env, [[exception description] UTF8String]).ThrowAsJavaScriptException();
        return env.Undefined();
    }
}

// 获取监听状态
Napi::Value IsListening(const Napi::CallbackInfo& info) {
    return Napi::Boolean::New(info.Env(), state.isListening);
}

// 初始化模块
Napi::Object Init(Napi::Env env, Napi::Object exports) {
    @try {
        state.isListening = false;
        state.localMonitor = nil;
        state.globalMonitor = nil;
        state.lastEventTime = 0;
        state.lastModifierFlags = 0;
        
        exports.Set("start", Napi::Function::New(env, Start));
        exports.Set("stop", Napi::Function::New(env, Stop));
        exports.Set("isListening", Napi::Function::New(env, IsListening));
        
        return exports;
        
    } @catch (NSException* exception) {
        NSLog(@"Error initializing module: %@", exception);
        Napi::Error::New(env, [[exception description] UTF8String]).ThrowAsJavaScriptException();
        return exports;
    }
}

NODE_API_MODULE(command_key_listener, Init) 