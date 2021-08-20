//
//  ContentView.swift
//  Infini-iOS
//
//  Created by xan-m on 8/5/21.
//

import SwiftUI
import SwiftUICharts
import CoreData

struct ContentView: View {
	
	@EnvironmentObject var pageSwitcher: PageSwitcher
	@EnvironmentObject var bleManager: BLEManager

	@AppStorage("autoconnect") var autoconnect: Bool = false
	@AppStorage("autoconnectUUID") var autoconnectUUID: String = ""
	
	init() {
		UINavigationBar.appearance().setBackgroundImage(UIImage(), for: UIBarMetrics.default)
		UINavigationBar.appearance().shadowImage = UIImage()
		UINavigationBar.appearance().isTranslucent = true
		UINavigationBar.appearance().tintColor = .clear
		UINavigationBar.appearance().backgroundColor = .clear
	}
	
	var body: some View {
		let drag = DragGesture()
			// this drag gesture allows swiping right to open the side menu and left to close the side menu
			.onEnded {
				if $0.translation.width < -100 {
					withAnimation {
						self.pageSwitcher.showMenu = false
					}
				} else if $0.translation.width > 100 {
					withAnimation {
						self.pageSwitcher.showMenu = true
					}
				}
			}
		// let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
		
		return NavigationView {
			GeometryReader { geometry in
				ZStack(alignment: .leading) {
					MainView()
						.sheet(isPresented: $pageSwitcher.connectViewLoad, content: {
							// pop-up menu to connect to a device
							Connect().environmentObject(self.bleManager)
						})
						.frame(width: geometry.size.width, height: geometry.size.height)
						.offset(x: self.pageSwitcher.showMenu ? geometry.size.width/2 : 0)
						.disabled(self.pageSwitcher.showMenu ? true : false)
						.overlay(Group {
							// this overlay lets you tap on the main screen to close the side menu. swiftUI requires a view that is not Color.clear and has any opacity level > 0
							if pageSwitcher.showMenu {
								Color.white
									.opacity(pageSwitcher.showMenu ? 0.01 : 0)
									.onTapGesture {
										withAnimation {
											pageSwitcher.showMenu = false
										}
									}
							}
						})
						// TODO: decide if this matters? I want the graph to show up because I spent a lot of time on it, but is it important enough to pollute it with a ton of data at the expense of the phone's processing power?
						// P.S. don't forget timer above the navigation view
						//
						//.onReceive(timer) { _ in
						//	bleManager.batChartDataPoints.append(bleManager.updateChartInfo(data: bleManager.batteryLevel, heart: false))
						//}
						.onAppear(){
							// if autoconnect is set, start scan ASAP, but give bleManager half a second to start up
							DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
								if autoconnect && bleManager.isSwitchedOn {
									self.bleManager.startScanning()
								}
							})
							if (autoconnect && autoconnectUUID == "") || (!autoconnect && !bleManager.isConnectedToPinetime) {
								DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
									withAnimation {
										pageSwitcher.connectViewLoad = true
									}
								})
							}
						}
					if self.pageSwitcher.showMenu {
						SideMenu(isOpen: self.$pageSwitcher.showMenu)
							.frame(width: geometry.size.width/2)
							.transition(.move(edge: .leading))
							.ignoresSafeArea()
					}
				}
				.navigationBarItems(leading: (
					Button(action: {
						withAnimation {
							self.pageSwitcher.showMenu.toggle()
						}
					}) {
						Image(systemName: "line.horizontal.3")
							.padding(.vertical, 10)
							.padding(.horizontal, 7)
							.imageScale(.large)
							.foregroundColor(Color.gray)
					}
				))
				.background(Color.black)
				.navigationBarTitleDisplayMode(.inline)
			}
			.gesture(drag)
		}
	}
}
	
struct MainView: View {

	@EnvironmentObject var pageSwitcher: PageSwitcher
	@EnvironmentObject var bleManager: BLEManager
	
	
	var body: some View {
		switch pageSwitcher.currentPage {
		case .dfu:
			DFU_Page()
		case .status:
			DeviceView()
		case .settings:
			Settings_Page()
		}
	}
}

	
struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
			.environmentObject(PageSwitcher())
			.environmentObject(BLEManager())
	}
}

