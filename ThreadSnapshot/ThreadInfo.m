//
//  ThreadInfo.m
//  AppleMiniDumpApp
//
//  Created by mjzheng on 2019/6/28.
//  Copyright © 2019年 mjzheng. All rights reserved.
//

#import "ThreadInfo.h"
#import <mach/mach.h>
#import "KSDynamicLinker.h"

#pragma -mark DEFINE MACRO FOR DIFFERENT CPU ARCHITECTURE
#if defined(__arm64__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(3UL))
#define THREAD_STATE_COUNT ARM_THREAD_STATE64_COUNT
#define THREAD_STATE ARM_THREAD_STATE64
#define FRAME_POINTER __fp
#define STACK_POINTER __sp
#define INSTRUCTION_ADDRESS __pc

#elif defined(__arm__)
#define DETAG_INSTRUCTION_ADDRESS(A) ((A) & ~(1UL))
#define THREAD_STATE_COUNT ARM_THREAD_STATE_COUNT
#define THREAD_STATE ARM_THREAD_STATE
#define FRAME_POINTER __r[7]
#define STACK_POINTER __sp
#define INSTRUCTION_ADDRESS __pc

#elif defined(__x86_64__)
#define DETAG_INSTRUCTION_ADDRESS(A) (A)
#define THREAD_STATE_COUNT x86_THREAD_STATE64_COUNT
#define THREAD_STATE x86_THREAD_STATE64
#define FRAME_POINTER __rbp
#define STACK_POINTER __rsp
#define INSTRUCTION_ADDRESS __rip

#elif defined(__i386__)
#define DETAG_INSTRUCTION_ADDRESS(A) (A)
#define THREAD_STATE_COUNT x86_THREAD_STATE32_COUNT
#define THREAD_STATE x86_THREAD_STATE32
#define FRAME_POINTER __ebp
#define STACK_POINTER __esp
#define INSTRUCTION_ADDRESS __eip

#endif

#define CALL_INSTRUCTION_FROM_RETURN_ADDRESS(A) (DETAG_INSTRUCTION_ADDRESS((A)) - 1)

#if defined(__LP64__)
#define TRACE_FMT         @"%-4d%-31s 0x%016lx %s + %lu\n"
#define POINTER_FMT       "0x%016lx"
#define POINTER_SHORT_FMT "0x%lx"
#else
#define TRACE_FMT         @"%-4d%-31s 0x%08lx %s + %lu\n"
#define POINTER_FMT       "0x%08lx"
#define POINTER_SHORT_FMT "0x%lx"
#endif

#define MAX_BACKTRACE 50

typedef struct StackFrameEntry
{
    const struct StackFrameEntry *const previous; // 低地址
    const uintptr_t return_address; // 高地址
} StackFrameEntry;

@implementation ThreadInfo

+(NSString*) getAllThreadStack:(float*) appCpu
{
    thread_act_array_t threads;
    mach_msg_type_number_t thread_count = 0;
    const task_t this_task = mach_task_self();
    kern_return_t kr = task_threads(this_task, &threads, &thread_count);
    if(kr != KERN_SUCCESS)
    {
        return @"Fail to enum threads";
    }
    
    *appCpu = 0;
    NSMutableString *resultString = [[NSMutableString alloc] init];
    for (int i=0; i<thread_count; i++)
    {
        thread_t thread = threads[i];
        NSString* threadName = nil;
        float threadCpu = getThreadCpuEx(thread, &threadName);
        [resultString appendFormat:@"\nThread %d Name :[%@] Cpu:[%.2f]\n", i, threadName, threadCpu];
        [resultString appendFormat:@"Thread %d:\n", i];
        NSString* stack = getThreadStack(i, thread);
        [resultString appendFormat:@"%@", stack];
        *appCpu += threadCpu;
    }
    NSString* allThreadStack = [resultString copy];
    NSLog(@"%@", allThreadStack);
    NSLog(@"app cpu %.2f", *appCpu);
    return allThreadStack;
}

// C function
NSString* getThreadStack(int index, thread_t thread)
{
    // 获取线程的ebp 和esp, 用于调用链重构
    _STRUCT_MCONTEXT machineContext;
    if(!thread_get_state_ex(thread, &machineContext))
    {
        return [NSString stringWithFormat:@"Fail to get thread[%u] state", thread];
    }
    const uintptr_t instructionAddress = mach_instructionAddress(&machineContext);
    if(instructionAddress == 0)
    {
        [NSString stringWithFormat:@"Fail to get thread[%u] instruction address", thread];
    }
   
    int i = 0;
    uintptr_t backtraceBuffer[MAX_BACKTRACE];
    memset(backtraceBuffer, 0, sizeof(backtraceBuffer));
    backtraceBuffer[i++] = instructionAddress;
    uintptr_t linkRegister = mach_linkRegister(&machineContext);
    if (linkRegister)
    {
        backtraceBuffer[i++] = linkRegister;
    }
    
    StackFrameEntry frame = {0};
    const uintptr_t framePtr = mach_framePointer(&machineContext);

    if(framePtr == 0 || mach_copyMem((void *)framePtr, &frame, sizeof(frame)) != KERN_SUCCESS)
    {
        return @"Fail to get frame pointer";
    }

    for(; i < MAX_BACKTRACE; i++)
    {
        backtraceBuffer[i] = frame.return_address;
        if(backtraceBuffer[i] == 0 || frame.previous == 0
           || mach_copyMem(frame.previous, &frame,sizeof(frame)) != KERN_SUCCESS)
        {
            break;
        }
    }
    
    NSMutableString *resultString = [[NSMutableString alloc] init];
    for (int j=0; j<i; j++)
    {
        NSString* frameEntry = getFrameEntry(j, backtraceBuffer[j]);
        [resultString appendString: frameEntry];
    }
    
    [resultString appendFormat:@"\n"];
    
    return [resultString copy];
}

#pragma -mark HandleMachineContext
bool thread_get_state_ex(thread_t thread, _STRUCT_MCONTEXT *machineContext)
{
    mach_msg_type_number_t state_count = THREAD_STATE_COUNT;
    kern_return_t kr = thread_get_state(thread, THREAD_STATE, (thread_state_t)&machineContext->__ss, &state_count);
    return (kr == KERN_SUCCESS);
}

uintptr_t mach_instructionAddress(mcontext_t const machineContext)
{
    return machineContext->__ss.INSTRUCTION_ADDRESS;
}

uintptr_t mach_linkRegister(mcontext_t const machineContext)
{
#if defined(__i386__) || defined(__x86_64__)
    return 0;
#else
    return machineContext->__ss.__lr;
#endif
}

uintptr_t mach_framePointer(mcontext_t const machineContext)
{
    return machineContext->__ss.FRAME_POINTER;
}

uintptr_t mach_stackPointer(mcontext_t const machineContext)
{
    return machineContext->__ss.STACK_POINTER;
}

kern_return_t mach_copyMem(const void *const src, void *const dst, const size_t numBytes)
{
    vm_size_t bytesCopied = 0;
    return vm_read_overwrite(mach_task_self(), (vm_address_t)src, (vm_size_t)numBytes, (vm_address_t)dst, &bytesCopied);
}

NSString* getFrameEntry(const int entryNum, const uintptr_t address)
{
    Dl_info dlInfo;
    ksdl_dladdr(address, &dlInfo);
    
    char faddrBuff[20];
    char saddrBuff[20];
    const char* fname = bs_lastPathEntry(dlInfo.dli_fname);
    if(fname == NULL)
    {
        sprintf(faddrBuff, POINTER_FMT, (uintptr_t)dlInfo.dli_fbase);
        fname = faddrBuff;
    }
    
    uintptr_t offset = address - (uintptr_t)dlInfo.dli_saddr;
    const char* sname = dlInfo.dli_sname;
    const char* pUnused = "<redacted>";
    if(sname == NULL || 0 == strcmp(sname, pUnused))
    {
        sprintf(saddrBuff, POINTER_FMT, (uintptr_t)dlInfo.dli_fbase);
        sname = saddrBuff;
        offset = address - (uintptr_t)dlInfo.dli_fbase;
    }
    
    return [NSString stringWithFormat:TRACE_FMT , entryNum, fname, (uintptr_t)address, sname, offset];
}

float getThreadCpuEx(thread_t thread, NSString** pThreadName)
{
    float cpu = 0;
    mach_msg_type_number_t thread_info_count = THREAD_INFO_MAX;
    thread_info_data_t thinfo;
    kern_return_t kr = thread_info(thread, THREAD_EXTENDED_INFO, (thread_info_t)thinfo, &thread_info_count);
    if (kr != KERN_SUCCESS)
    {
        return cpu;
    }
    
    thread_extended_info_t basic_info_th = (thread_extended_info_t)thinfo;
    if (!(basic_info_th->pth_flags & TH_FLAGS_IDLE))
    {
        cpu = basic_info_th->pth_cpu_usage / (float)TH_USAGE_SCALE * 100.0;
    }
    *pThreadName = [NSString stringWithUTF8String:basic_info_th->pth_name];
    return cpu;
}

const char* bs_lastPathEntry(const char* const path)
{
    if(path == NULL)
    {
        return NULL;
    }
    
    char* lastFile = strrchr(path, '/');
    return lastFile == NULL ? path : lastFile + 1;
}

@end
