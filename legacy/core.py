import struct
import time
from Cocoa import NSWorkspace
import pyautogui
from Quartz import CoreGraphics as CG
from PIL import Image

processList = []

# 定义取色坐标
captureX = 5
captureY = 35

colorMode = "SRGB"

# 定义按键
keysDict = {}

# 苹果iMac颜色模式
keysDict["iMac"] = [
    {"r": 10, "g": 6, "b": 1, "key": "1"},
    {"r": 14, "g": 6, "b": 1, "key": "2"},
    {"r": 18, "g": 7, "b": 1, "key": "3"},
    {"r": 23, "g": 7, "b": 1, "key": "4"},
    {"r": 27, "g": 7, "b": 1, "key": "5"},
    {"r": 32, "g": 8, "b": 1, "key": "6"},
    {"r": 36, "g": 8, "b": 2, "key": "7"},
    {"r": 41, "g": 9, "b": 2, "key": "8"},
    {"r": 45, "g": 9, "b": 2, "key": "9"},
    {"r": 50, "g": 10, "b": 3, "key": "0"},
    {"r": 54, "g": 11, "b": 3, "key": "-"},
    {"r": 59, "g": 12, "b": 3, "key": "="},
    {"r": 64, "g": 12, "b": 4, "key": "f1"},
    {"r": 68, "g": 13, "b": 4, "key": "f2"},
    {"r": 73, "g": 14, "b": 5, "key": "f3"},
    {"r": 77, "g": 15, "b": 6, "key": "f4"},
    {"r": 82, "g": 16, "b": 6, "key": "f5"},
    {"r": 87, "g": 17, "b": 7, "key": "f6"},
    {"r": 91, "g": 18, "b": 8, "key": "f7"},
    {"r": 96, "g": 19, "b": 8, "key": "f8"},
    {"r": 100, "g": 20, "b": 9, "key": "f9"},
    {"r": 105, "g": 21, "b": 10, "key": "f10"},
    {"r": 110, "g": 22, "b": 11, "key": "f11"},
    {"r": 114, "g": 23, "b": 12, "key": "f12"}
]

# 设置显示器颜色描述文件为SRGB
keysDict["SRGB"] = [
    {"r": 10, "g": 6, "b": 0, "key": "1"},
    {"r": 15, "g": 6, "b": 0, "key": "2"},
    {"r": 20, "g": 6, "b": 0, "key": "3"},
    {"r": 25, "g": 6, "b": 0, "key": "4"},
    {"r": 30, "g": 6, "b": 0, "key": "5"},
    {"r": 35, "g": 6, "b": 0, "key": "6"},
    {"r": 40, "g": 6, "b": 0, "key": "7"},
    {"r": 45, "g": 6, "b": 0, "key": "8"},
    {"r": 50, "g": 6, "b": 0, "key": "9"},
    {"r": 55, "g": 6, "b": 0, "key": "0"},
    {"r": 60, "g": 6, "b": 0, "key": "-"},
    {"r": 65, "g": 6, "b": 0, "key": "="},
    {"r": 70, "g": 6, "b": 0, "key": "f1"},
    {"r": 75, "g": 6, "b": 0, "key": "f2"},
    {"r": 80, "g": 6, "b": 0, "key": "f3"},
    {"r": 85, "g": 6, "b": 0, "key": "f4"},
    {"r": 90, "g": 6, "b": 0, "key": "f5"},
    {"r": 95, "g": 6, "b": 0, "key": "f6"},
    {"r": 100, "g": 6, "b": 0, "key": "f7"},
    {"r": 105, "g": 6, "b": 0, "key": "f8"},
    {"r": 110, "g": 6, "b": 0, "key": "f9"},
    {"r": 115, "g": 6, "b": 0, "key": "f10"},
    {"r": 120, "g": 6, "b": 0, "key": "f11"},
    {"r": 125, "g": 6, "b": 0, "key": "f12"}
]

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
    print('{0}\t{1:>10s}\t{2:30s}'.format('序号', 'PID', '窗口名称'))

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
    lastRed = 255
    lastGreen = 255
    lastBlue = 255

    # 获取激活的窗口
    while True:
        starttime = time.time()

        # 获取传入窗口的详细信息
        winDesc = CG.CGWindowListCreateDescriptionFromArray([winNumber])[0]
        winPID = winDesc.get('kCGWindowOwnerPID', 0)
        winName = winDesc.get("kCGWindowName", "")
        winOwnerName = winDesc.get('kCGWindowOwnerName', '')
        winLayer = winDesc.get('kCGWindowLayer')
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

            if winX == 0 and winY == 0:
                y = 5

            #取色逻辑
            colorRed = 0
            colorGreen = 0
            colorBlue = 0
            colorMethod = 1

            if colorMethod == 0:
                # 较慢
                image = Image.frombytes("RGBA", (width, height), data)
                (colorBlue, colorGreen, colorRed, a) = image.getpixel((x, y))
            elif colorMethod == 1:
                # 较快
                offset = 4 * ((width * int(round(y))) + int(round(x)))
                colorBlue, colorGreen, colorRed, a = struct.unpack_from("BBBB", data, offset=offset)
            elif colorMethod == 2:
                img1 = Image.frombytes("RGBA", (width, height), data)
                b, g, r, a = img1.split()
                img1 = Image.merge("RGBA", (r, g, b, a))
                img1.show()
                break
            elif colorMethod == 3:
                #pyautogui.write("hello world!")
                loc = pyautogui.locateOnScreen("indictor.png")
                print(loc)
                print(pyautogui.size())
                print(width, height)

            if lastRed != colorRed or lastGreen != colorGreen or lastBlue != colorBlue:
                lastRed = colorRed
                lastGreen = colorGreen
                lastBlue = colorBlue
                print('Color Change to ', colorRed, colorGreen, colorBlue)

            if colorRed == 0 and colorGreen == 0 and colorBlue == 0:
                time.sleep(0.3)
            else:
                # 符合颜色过滤条件，根据r的值发送按键
                # 苹果的截图，不同设备截出来的颜色都会不一样，用genius test D1来测试按键
                for item in keysDict[colorMode]:
                    if colorRed - 1 <= item["r"] <= colorRed + 1 and item["g"] == colorGreen and item["b"] == colorBlue:
                        print("Press key: ", item["key"])
                        pyautogui.press(item["key"])
                        break

            time.sleep(0.2)
            #endtime = time.time()
            #elasped = endtime - starttime
            #print('tick in ' + str(elasped) + 's')
        else:
            print("目标窗口 [{0} - {1}] 未激活，等待中...".format(winName, winOwnerName))
            lastRed = 255
            lastGreen = 255
            lastBlue = 255
            time.sleep(2)


if __name__ == '__main__':
    winNumber = None

    # 显示正在运行的进程列表并提示用户选择
    while True:
        print("")
        print("欢迎使用 Genius for Mac 1.0")
        print("================================")
        print("非常重要：Mac用户请在【设置->显示器->颜色】中将【显示器描述文件】设置为【sRGB】才能捕获正确颜色值！")
        print("================================")
        ListProcess()
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
            print("开始监控（可以按Ctrl+C退出）...")
            capture(winNumber)
        except KeyboardInterrupt:
            print("监控结束。")
