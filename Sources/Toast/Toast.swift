// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import Combine

public struct ToastView<V: View>: ViewModifier {
  
  @Environment(\.dismiss) private var dismiss
  @Binding var isPresented: Bool
  @State private var timer: Timer?
  @State private var isActive = false
  @State private var currentState = false
  
  private let toastContent: V
  private let style: ToastStyle
  
  public init(_ isPresented: Binding<Bool>,
              style: ToastStyle = .init(),
              @ViewBuilder content: @escaping() -> V) {
    _isPresented = isPresented
    toastContent = content()
    self.style = style
  }
  
  public func body(content: Content) -> some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .overlay(alignment: style.alignment, content: toastContentView)
  }
  
  @ViewBuilder
  private func toastContentView() -> some View {
    if isPresented {
      Group {
        switch style.style {
        case .fade:
          toastContent
            .modifier(ToastFade(isPresented: $isPresented, style: style))
        case .slide:
          toastContent
            .modifier(ToastSide(isPresented: $isPresented, style: style))
        case .scale:
          toastContent
            .modifier(ToastSide(isPresented: $isPresented, style: style))
        }
      }
      .onTapGesture(perform: tapToDismiss)
      .onAppear(perform: setUpView)
      .onDisappear { isActive.toggle() }
      .onReceive(Just(isPresented), perform: update)
    }
  }
  
  private func setUpView() {
    resetTimer()
    isActive = true
  }
  
  private func resetTimer() {
    if let timeout = style.hide, isPresented {
      DispatchQueue.main.async {
        timer?.invalidate()
        timer = .scheduledTimer(
          withTimeInterval: timeout, repeats: false) { _ in
            dismissToastView()
          }
      }
    }
  }
  
  private func dismissToastView() {
    withAnimation(style.animation ?? .default) {
      timer?.invalidate()
      timer = nil
      isPresented = false
      dismiss()
    }
  }
  
  private func tapToDismiss() {
    if style.tapToDismiss {
      dismissToastView()
    }
  }
  
  private func update(_ state: Bool) {
    guard state != currentState else { return }
    currentState = state
    guard isActive, currentState else { return }
    resetTimer()
  }
}
  // MARK: - ToastOptions
  
  public struct ToastStyle {
    
    public var alignment: Alignment
    public var hide: TimeInterval?
    public var animation: Animation?
    public var style: Style
    public var tapToDismiss: Bool
    
    public init(
      alignment: Alignment = .bottom,
      hide: TimeInterval? = 2.0,
      animation: Animation? = nil,
      tapToDismiss: Bool = true,
      style: Style = .slide) {
        self.alignment = alignment
        self.hide = hide
        self.animation = animation
        self.tapToDismiss = tapToDismiss
        self.style = style
      }
    
    static public let slide = ToastStyle(
      alignment: .bottom,
      hide: 3.0,
      tapToDismiss: true,
      style: .slide)
    
    static public let fade = ToastStyle(
      alignment: .bottom,
      hide: 3.0,
      tapToDismiss: true,
      style: .fade)
    
    static public let scale = ToastStyle(
      alignment: .bottom,
      hide: 3.0,
      tapToDismiss: true,
      style: .scale)
  }
  
  // MARK: - Toast Style
  
  public enum Style {
    case fade, slide, scale
  }
  
  struct ToastFade: ViewModifier {
    @Binding var isPresented: Bool
    let style: ToastStyle?
    
    func body(content: Content) -> some View {
      content
        .transition(.opacity.animation(style?.animation ?? .linear))
        .opacity(isPresented ? 1 : 0)
        .zIndex(1.0)
    }
  }
  
  struct ToastSide: ViewModifier {
    @Binding var isPresented: Bool
    let style: ToastStyle?
    
    private var transitionEdge: Edge {
      guard let edge = style?.alignment else { return .top }
      switch edge {
      case .top, .topLeading, .topTrailing: return .top
      case .bottom, .bottomLeading, .bottomTrailing: return .bottom
      default: return .top
      }
    }
    
    func body(content: Content) -> some View {
      content
        .transition(.move(edge: transitionEdge).combined(with: .opacity))
        .animation(style?.animation ?? .default, value: isPresented)
        .opacity(isPresented ? 1 : 0)
        .zIndex(1.0)
    }
}

struct ToastScale: ViewModifier {
  @Binding var isPresented: Bool
  let style: ToastStyle?
  
  func body(content: Content) -> some View {
    content
      .transition(.scale.animation(style?.animation ?? .linear))
      .opacity(isPresented ? 1 : 0)
      .zIndex(1.0)
  }
}

// MARK: - View Modifier

public extension View {
  
  func showToast<V: View>(
    _ isPresented: Binding<Bool>,
    style: ToastStyle = .slide,
    @ViewBuilder content: @escaping () -> V) -> some View {
      modifier(ToastView(isPresented, style: style, content: content))
    }
  func showToast<V: View, Item: Identifiable>(
    _ item: Binding<Item?>?,
    style: ToastStyle = .slide,
    @ViewBuilder content: @escaping () -> V) -> some View {
      
      let binding = Binding<Bool> {
        item?.wrappedValue != nil
      } set: { value in
        if !value { item?.wrappedValue = nil }
      }
      return modifier(ToastView(binding, style: style, content: content))
    }
  
  func showToast(_ item: Binding<ToastMessage?>) -> some View {
    self.showToast(item) {
      HStack {
        Text(item.wrappedValue?.message ?? "")
          .padding()
          .background(
            Capsule()
              .foregroundStyle((item.wrappedValue?.style ?? .green).opacity(0.3))
          )
      }
    }
  }
}

// MARK: - ToastMessage

public struct ToastMessage: Identifiable, Equatable {
  public var id: String = UUID().uuidString
  public var message: String
  public var style: Color
  
  public init(_ message: String, style: Color = .blue) {
    self.message = message
    self.style = style
  }
}
