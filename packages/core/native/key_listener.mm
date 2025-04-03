/**
 * @file key_listener.mm
 * @brief macOS 全局键盘事件监听器的原生实现
 * 
 * 这个模块实现了一个全局键盘事件监听器，可以在应用内外捕获键盘事件。
 * 主要特点：
 * 1. 同时支持应用内和应用外的键盘事件监听
 * 2. 每个按键在一次按下过程中只触发一次事件（无论是普通键还是修饰键）
 * 3. 不区分按键类型，统一处理所有按键事件
 * 
 * 实现原理：
 * 1. 使用 NSEvent 的 addLocalMonitorForEventsMatchingMask 监听应用内按键
 * 2. 使用 NSEvent 的 addGlobalMonitorForEventsMatchingMask 监听应用外按键
 * 3. 通过 pressedKeys 字典跟踪按键状态，确保每个按键只触发一次
 * 4. 使用时间戳检查作为额外的防重复保护机制
 * 
 * 使用注意：
 * 1. 需要确保应用有辅助功能权限（Accessibility Permission）
 * 2. 建议在应用启动时调用 start，退出时调用 stop
 * 3. 回调函数会收到一个包含 keyCode 的事件对象
 * 4. 不要依赖事件的触发频率，每个按键在按下时只会触发一次
 * 
 * 示例用法：
 * ```javascript
 * const keyListener = require('@coffic/core');
 * keyListener.start((event) => {
 *   console.log('Key pressed:', event.keyCode);
 * });
 * ```
 * 
 * 已知限制：
 * 1. 只支持 macOS 平台
 * 2. 需要用户授予辅助功能权限
 * 3. 不提供按键的字符信息，只提供 keyCode
 * 
 * 内部实现细节：
 * 1. 使用 NSMutableDictionary 跟踪按键状态
 * 2. 统一处理 KeyDown 和 FlagsChanged 事件
 * 3. 在按键释放时（KeyUp 或 FlagsChanged）清理状态
 * 4. 使用线程安全的回调机制确保事件处理的可靠性
 */

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
    NSMutableDictionary* pressedKeys;  // 记录按下的键
} state;

// 事件数据结构
struct KeyEventData {
    uint16_t keyCode;
};

// 安全地处理事件回调
bool SafeHandleKeyEvent(NSEvent* event) {
    @try {
        if (!state.isListening || !state.tsfn) {
            return false;
        }

        // 检查事件时间戳，防止重复事件
        NSTimeInterval currentTime = event.timestamp;
        if (currentTime - state.lastEventTime < 0.01) { // 10毫秒内的事件视为重复
            return false;
        }

        NSNumber* keyCode = @(event.keyCode);
        
        if (event.type == NSEventTypeKeyDown) {
            // 如果键已经按下，不再触发
            if ([state.pressedKeys objectForKey:keyCode]) {
                return false;
            }
            // 记录键的按下状态
            [state.pressedKeys setObject:@YES forKey:keyCode];
            state.lastEventTime = currentTime;
        } else if (event.type == NSEventTypeKeyUp) {
            // 键释放时，移除记录
            [state.pressedKeys removeObjectForKey:keyCode];
            return false;
        } else if (event.type == NSEventTypeFlagsChanged) {
            // 修饰键的按下事件
            static NSUInteger lastFlags = 0;
            NSUInteger newFlags = event.modifierFlags;
            
            // 如果新的标志位比旧的少，说明是释放事件，移除记录并返回
            if (newFlags < lastFlags) {
                [state.pressedKeys removeObjectForKey:keyCode];
                lastFlags = newFlags;
                return false;
            }
            
            // 如果标志位没有变化，不处理
            if (newFlags == lastFlags) {
                return false;
            }
            
            // 如果键已经按下，不再触发
            if ([state.pressedKeys objectForKey:keyCode]) {
                return false;
            }
            
            // 记录新的状态
            [state.pressedKeys setObject:@YES forKey:keyCode];
            lastFlags = newFlags;
            state.lastEventTime = currentTime;
        } else {
            // 其他类型的事件不处理
            return false;
        }

        KeyEventData* data = new KeyEventData();
        data->keyCode = event.keyCode;
        
        state.tsfn.NonBlockingCall(data, [](Napi::Env env, Napi::Function jsCallback, KeyEventData* data) {
            @autoreleasepool {
                Napi::Object event = Napi::Object::New(env);
                event.Set("keyCode", data->keyCode);
                jsCallback.Call({event});
                delete data;
            }
        });
        return true;

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
        state.pressedKeys = [[NSMutableDictionary alloc] init];
        
        // 添加本地按键监听器
        state.localMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskKeyUp | NSEventMaskFlagsChanged)
            handler:^NSEvent *(NSEvent *event) {
                SafeHandleKeyEvent(event);
                return event;
            }];
        
        // 添加全局按键监听器
        state.globalMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:(NSEventMaskKeyDown | NSEventMaskKeyUp | NSEventMaskFlagsChanged)
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
            [state.pressedKeys release];
            state.pressedKeys = nil;
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
        
        // 清理按键状态
        [state.pressedKeys release];
        state.pressedKeys = nil;
        
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
        state.pressedKeys = nil;
        
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