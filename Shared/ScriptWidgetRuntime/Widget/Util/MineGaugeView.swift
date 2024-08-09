//
//  MineGaugeViewSample.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/4/10.
//

import SwiftUI

public struct MineGaugeViewSection: Identifiable {
    public var id = UUID()
    var color: Color
    var value: Double
    
    public init(color: Color, value: Double) {
        self.color = color
        self.value = value
    }
}

struct _MineGaugeElement: View {
    var section: MineGaugeViewSection
    var startAngle: Double
    var trim: ClosedRange<CGFloat>
    var lineCap: CGLineCap = .butt
    var thickness:Int = 10
    
    
    var body: some View {
        GeometryReader { geometry in
            let lineWidth = geometry.size.height / CGFloat(thickness)
            
            section.color
                .mask(Circle()
                        .trim(from: trim.lowerBound, to: trim.upperBound)
                        .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: lineCap))
                        .rotationEffect(Angle(degrees: startAngle))
                        .padding(lineWidth/2)
                )
        }
    }
}

struct _MineGaugeNeedleView: View {
    var angle: Double
    var value: Double = 0.0
    var needleColor: Color = Color.black.opacity(0.8)
    var thickness:Int = 10
    
    var body: some View {
        // 90 to start in south orientation, then add offset to keep gauge symetric
        let startAngle = 90 + (360.0-angle) / 2.0
        let needleAngle = startAngle + value * angle
        
        GeometryReader { geometry in
            ZStack
            {
                let rectWidth = geometry.size.height / 2
                let rectHeight = geometry.size.height / 20
                
                Rectangle()
                    .fill(needleColor.opacity(0.8))
                    .cornerRadius(geometry.size.height / CGFloat(thickness) / 2)
                    .frame(width: rectWidth, height: rectHeight)
                    .offset(x: rectWidth / 2)
                
                Circle()
                    .fill(needleColor)
                    .frame(width: geometry.size.height / CGFloat(thickness))
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .rotationEffect(Angle(degrees: needleAngle))
    }
}

public struct MineGaugeView<Label>: View where Label : View {
    var angle: Double
    var value: Double
    var sections: [MineGaugeViewSection]
    var label: () -> Label
    let thickness: Int
    let needleColor: Color

    public init(angle: Double, value: Double, thickness: Int, needleColor: Color, sections: [MineGaugeViewSection], @ViewBuilder label: @escaping () -> Label) {
        self.angle = angle
        self.sections = sections
        self.value = value
        self.label = label
        self.thickness = thickness
        self.needleColor = needleColor
    }
    
    public var body: some View {
        // 90 to start in south orientation, then add offset to keep gauge symetric
        let startAngle = 90 + (360.0-angle) / 2.0
        
        ZStack {
            ForEach(sections) { section in
                // Find index of current section to sum up already covered areas in percent
                if let index = sections.firstIndex(where: {$0.id == section.id}) {
                    let alreadyCovered = sections[0..<index].reduce(0) { $0 + $1.value}
                    
                    // 0.001 is a small offset to fill a gap
                    let sectionSize = section.value * (angle / 360.0)// + 0.001
                    let sectionStartAngle = startAngle + alreadyCovered * angle
                    
                    _MineGaugeElement(section: section, startAngle: sectionStartAngle, trim:  0...CGFloat(sectionSize), thickness: thickness)
                    
                    // Add round caps at start and end
                    if index == 0 || index == sections.count - 1{
                        let capSize: CGFloat = 0.001
                        let startAngle: Double = index == 0 ? sectionStartAngle : startAngle + angle
                        
                        _MineGaugeElement(section: section, startAngle: startAngle, trim: 0...capSize,lineCap: .round, thickness: thickness)
                    }
                }
            }
            .overlay(label(), alignment: .bottom)
            
            _MineGaugeNeedleView(angle: angle, value: value, needleColor: needleColor, thickness: thickness)
        }
    }
}

let value = 0.6
let angle = 260.0
let sections = [MineGaugeViewSection(color: .green, value: 0.1),
                MineGaugeViewSection(color: .yellow, value: 0.1),
                MineGaugeViewSection(color: .orange, value: 0.1),
                MineGaugeViewSection(color: .red, value: 0.1),
                MineGaugeViewSection(color: .purple, value: 0.2),
                MineGaugeViewSection(color: .blue, value: 0.4)]

struct MineGaugeViewSample: View {
    var body: some View {
        VStack {
            MineGaugeView(angle: angle, value: value,thickness: 10,needleColor:Color.black, sections: sections) {
                VStack {
                    Text("\(Int(value * 100)) %").font(.caption)
                    Text("Speed").font(.caption)
                }
            }
        }
    }
}

struct MineGaugeViewSample_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MineGaugeViewSample()
                .frame(width: 100,height: 100, alignment: .center)
                .background(Color.secondary)
                .previewLayout(.sizeThatFits)
            MineGaugeViewSample()
                .frame(width: 200,height: 200, alignment: .center)
                .background(Color.secondary)
                .previewLayout(.sizeThatFits)
            MineGaugeViewSample()
                .frame(width: 300,height: 300, alignment: .center)
                .background(Color.secondary)
                .previewLayout(.sizeThatFits)
        }
    }
}
