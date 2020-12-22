import struct
import time
from Cocoa import NSWorkspace
import pyautogui
from Quartz import CoreGraphics as CG
from PIL import Image

processList = []

# 定义取色坐标
captureX = 15
captureY = 15

# 获取进程列表并等待用户选择
def ListProcess():
    blackList = [
        'Bluetooth', 'Battery', 'WiFi', 'UserSwitcher', 'BentoBox', 'Siri', 'Clock', 'Menubar', 'Dock',
        'Item-0'
    ]

    # 获取进程列表
    winList = CG.CGWindowListCopyWindowInfo(
        CG.kCGWindowListOptionOnScreenOnly |
        CG.kCGWindowListExcludeDesktopElements,
        CG.kCGNullWindowID)

    # 序号
    idx = 0

    # 打印标题栏
    print('{0}\t{1:>10s}\t{2:30s}'.format('序号', 'PID', '进程名称'))

    for win in winList:
        name = win.get('kCGWindowName', '')
        nameOwner = win.get('kCGWindowOwnerName', '')
        winNumber = win.get('kCGWindowNumber', 0)
        winPID = win.get('kCGWindowOwnerPID', 0)

        if name != '' and name not in blackList:
            print('{0}\t{1:10d}\t{2:30s}'.format(idx, winPID, name))
            # add kCGWindowNumber to array
            processList.append(winNumber)
            idx = idx + 1

# 捕获核心逻辑
def capture(winNumber):
    # 获取激活的窗口
    #while True:
    for i in range(100000):
        starttime = time.time()

        # 获取传入窗口的详细信息
        winDesc = CG.CGWindowListCreateDescriptionFromArray([winNumber])[0]
        winPID = winDesc.get('kCGWindowOwnerPID', 0)
        #winOwnerName = winDesc.get('kCGWindowOwnerName', '')
        winBounds = winDesc.get('kCGWindowBounds', '{}')
        winX = winBounds.get("X", 0)
        winY = winBounds.get("Y", 0)
        winW = winBounds.get("Width", 0)
        winH = winBounds.get("Height", 0)

        activeWin = NSWorkspace.sharedWorkspace().activeApplication()

        if activeWin['NSApplicationProcessIdentifier'] == winPID:
            # 激活中的窗口和指定的窗口一致
            CGImageRef = CG.CGWindowListCreateImage(
                CG.CGRectInfinite,
                #CG.kCGWindowListOptionOnScreenOnly,
                CG.kCGWindowListOptionIncludingWindow | CG.kCGWindowListExcludeDesktopElements,
                winNumber,
                #CG.kCGNullWindowID,
                CG.kCGWindowImageDefault | CG.kCGWindowImageNominalResolution)

            prov = CG.CGImageGetDataProvider(CGImageRef)
            width = CG.CGImageGetWidth(CGImageRef)
            height = CG.CGImageGetHeight(CGImageRef)
            data = CG.CGDataProviderCopyData(prov)

            # 根据窗口坐标累加偏移量
            x = captureX + winX
            y = captureY + winY

            #取色逻辑
            colorRed = 0
            colorGreen = 0
            colorBlue = 0
            colorMethod = 1

            if colorMethod == 0:
                image = Image.frombytes("RGBA", (width, height), data)
                (colorBlue, colorGreen, colorRed, a) = image.getpixel((x, y))
            elif colorMethod == 1:
                offset = 4 * ((width * int(round(y))) + int(round(x)))
                colorBlue, colorGreen, colorRed, a = struct.unpack_from("BBBB", data, offset=offset)
            elif colorMethod == 2:
                img1 = Image.frombytes("RGBA", (width, height), data)
                b, g, r, a = img1.split()
                img1 = Image.merge("RGBA", (r, g, b, a))
                img1.show()
                break
            elif colorMethod == 3:
                pyautogui.write("hello world!")


            print(colorRed, colorGreen, colorBlue)

            # 符合颜色过滤条件，根据r的值发送按键
            if colorGreen == 6 and colorBlue == 0:
                if colorRed == 10:
                    pyautogui.press("1")
                elif colorRed == 15:
                    pyautogui.press("2")
                elif colorRed == 20:
                    pyautogui.press("3")
                elif colorRed == 25:
                    pyautogui.press("4")
                elif colorRed == 30:
                    pyautogui.press("5")
                elif colorRed == 35:
                    pyautogui.press("6")
                elif colorRed == 40:
                    pyautogui.press("7")
                elif colorRed == 45:
                    pyautogui.press("8")
                elif colorRed == 50:
                    pyautogui.press("9")
                elif colorRed == 55:
                    pyautogui.press("0")
                elif colorRed == 60:
                    pyautogui.press("-")
                elif colorRed == 65:
                    pyautogui.press("=")
                elif colorRed == 65:
                    pyautogui.press("=")
                elif colorRed == 65:
                    pyautogui.press("=")
                elif colorRed == 70:
                    pyautogui.press("f1")
                elif colorRed == 75:
                    pyautogui.press("f2")
                elif colorRed == 80:
                    pyautogui.press("f3")
                elif colorRed == 85:
                    pyautogui.press("f4")
                elif colorRed == 90:
                    pyautogui.press("f5")
                elif colorRed == 95:
                    pyautogui.press("f6")
                elif colorRed == 100:
                    pyautogui.press("f7")
                elif colorRed == 105:
                    pyautogui.press("f8")
                elif colorRed == 110:
                    pyautogui.press("f9")
                elif colorRed == 115:
                    pyautogui.press("f10")
                elif colorRed == 120:
                    pyautogui.press("f11")
                elif colorRed == 125:
                    pyautogui.press("f12")

            endtime = time.time()
            elasped = endtime - starttime
            print('done! in ' + str(elasped) + 's')
            #time.sleep(0.2)
        else:
            print("目标窗口未激活，等待中...")
            time.sleep(2)


if __name__ == '__main__':
    winNumber = None

    # 显示正在运行的进程列表并提示用户选择
    print("Listing process...")
    ListProcess()

    while True:
        data = input("请输入需要监控的序号:")

        try:
            inputData = eval(data)
            if type(inputData) == int and inputData >= 0 and inputData < len(processList):
                winNumber = processList[inputData]
                break
            else:
                print("无效的输入！")
        except:
            print("无效的输入！")
            pass

    # 启动捕获逻辑
    if winNumber is not None:
        try:
            print("开始监控...")
            capture(winNumber)
        except KeyboardInterrupt:
            print("监控结束。")

