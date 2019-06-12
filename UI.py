# -*- coding: utf-8 -*-
"""
Created on Tue Apr 30 14:41:42 2019

@author: Vincent Chen
"""

import sys ,os
from PyQt5.QtWidgets import QPushButton ,QSlider, QGridLayout ,QWidget,QLCDNumber,QFileDialog ,QLabel
from PyQt5.QtCore import Qt
from PyQt5 import QtCore
from PyQt5 import QtWidgets

class Btn(QPushButton):
    def __init__(self,name,id,parent):
        super(Btn,self).__init__(name,parent)
        self.id = id
        self.setFixedHeight(150)
        self.setStyleSheet("margin: 0px")
        self.clicked.connect(self.click)
    def click(self):
        if window.last != 100:
            window.b[window.last].setStyleSheet("margin: 0px")
        window.last = self.id
        window.b[window.last].setStyleSheet("background-color: gray")
        
class Btn2(QPushButton):
    def __init__(self,name,n,parent):
        super(Btn2,self).__init__(name,parent)
        self.n = n
        self.setFixedHeight(50)
        self.setStyleSheet("margin: 0px")
        self.clicked.connect(self.click)
    def click(self):
        if window.last != 100:
            f = open('title.txt','w')
            f.write(window.text)
            f = open('input.txt','w')
            if window.last == 1 or window.last == 2 or window.last == 4 :
                f.write(str(window.last+1) +"\n" +str(self.n) +"\n" + str(window.s.value()))
            else:
                f.write(str(window.last+1) +"\n" +str(self.n))
            os.popen("a.exe")

class sldr(QSlider):
    def __init__(self):
        super(sldr,self).__init__(Qt.Horizontal)
        self.setMinimum(0)
        self.setMaximum(100)
        self.setValue(0)
        

class Window(QWidget):
    def __init__(self):
        super().__init__()
        self.grid_layout = QGridLayout()
        self.setLayout(self.grid_layout)
        self.last = 100
        self.b = []
        
        self.title = "Photo Editing"
        self.top = 100
        self.left = 100
        self.width = 800
        self.height = 600
        self.InitWindow()
        
    def InitWindow(self):
        self.setWindowTitle(self.title)
        self.setGeometry(self.left,self.top,self.width,self.height)
        
        self.Buttons()
        self.FileUpload()
        self.slider()
        self.buttons2()
        
        self.show()
        
    def Buttons(self):
        self.b.append(Btn("Monochrome",0,self))
        self.b.append(Btn("Blur",1,self))
        self.b.append(Btn("Masaic",2,self))
        self.b.append(Btn("Focus Blur",3,self))
        self.b.append(Btn("Smallize",4,self))
        for i in range(0,5):
            self.grid_layout.addWidget(self.b[i], 0, i*2, 1, 2)
    
    def FileUpload(self):
        self.t = QLabel(self)
        self.t.setText("")
        self.text = ""
        self.FUbtn = QPushButton("Choose BMP Photo",self)
        self.FUbtn.clicked.connect(self.OpenFile)
        self.grid_layout.addWidget(self.t,1,1,1,6)
        self.grid_layout.addWidget(self.FUbtn,1,7,1,2)
        
    def OpenFile(self):
        file = QFileDialog.getOpenFileName(self, "openfile", "./" ,"(*.bmp)")
        temp = str(file)
        j=0
        t = ""
        for i in temp:
            if i == "'" :
                j += 1
                continue
            if j == 1 :
                t += i
        window.t.setText(t)
        window.text = t
        
    def slider(self):
        self.s = sldr()
        self.lcd = QLCDNumber(self)
        self.s.valueChanged.connect(self.lcd.display)
        self.grid_layout.addWidget(self.lcd, 2, 0, 1, 1)
        self.grid_layout.addWidget(self.s, 2, 1, 1 ,5)
    
    def buttons2(self):
        self.gpuButton = Btn2("transfer by gpu","g",self)
        self.cpuButton = Btn2("transfer by cpu","c",self)
        self.grid_layout.addWidget(self.cpuButton,2,6,1,2)
        self.grid_layout.addWidget(self.gpuButton,2,8,1,2)
        
if __name__ == "__main__" :
    app = QtCore.QCoreApplication.instance()
    if app is None:
        app = QtWidgets.QApplication(sys.argv)
    window = Window()
    sys.exit(app.exec())
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    