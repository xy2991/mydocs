# vis.js插件

## 简介：使用vis.js插件制作拓扑图，适用于vue框架

### 配置  "vis"："^4.21.0"

[安装方式]：http://visjs.org/

[GitHub地址]：https://github.com/almende/vis

### 属性：

- Network - edges（边缘）


| 名称 |  类型   | 默认 |        描述         |
|:-------:|:-----------:|:-------:|:-------------------:|
|arrows|object or string|undefined|默认设置箭头或创建对象控制箭头大小|
|arrowStrikethroughto |boolean | true |错误时，边缘停在箭头处|
|chosen|object or boolean| true |如果为true，则选择或悬停在边上将根据默认值更改其标签特征。如果为false，则选择边时不会更改|
|color| object or string| object| 可以使用'rgb(120,32,14)','#ffffff'或'red'等值标识各种情况下边缘线的颜色
|dashes|Array or Boolean|false |当为true，连接线为虚线|
|font|object or string|false|定义标签细节，可自行设置颜色、大小等基本信息|
|from|number or string||边缘位于两个节点之间，其中一个来自另一个节点|
|hoverWidth|Number or Function|0.5|假设在交互模块中启用悬停行为，hoverWidth会在用户使用鼠标悬停在其上时确定边缘的宽度|
|id|string|undefined|边缘的ID，可选；未提供时，UUID将被分配给边缘|
|label|string|undefined|边缘的标签|
|labelHighlightBold	|布尔|true|确定选择边缘时是否变为粗体。|
</br>

```
示例 :
var options = {
  edges:{
    arrows: {
      to:     {enabled: false, scaleFactor:1, type:'arrow'},
      middle: {enabled: false, scaleFactor:1, type:'arrow'},
      from:   {enabled: false, scaleFactor:1, type:'arrow'}
    },
    arrowStrikethrough: true,
    chosen: true,
    color: {
      color:'#848484',
      highlight:'#848484',
      hover: '#848484',
      inherit: 'from',
      opacity:1.0
    },
    dashes: false,
    font: {
      color: '#343434',
      size: 14, // px
      face: 'arial',
      background: 'none',
      strokeWidth: 2, // px
      strokeColor: '#ffffff',
      align: 'horizontal',
      multi: false,
      vadjust: 0,
    },
    hoverWidth: 1.5,
    physics: true,
    scaling:{
      min: 1,
      max: 15,
      label: {
        enabled: true,
        min: 14,
        max: 30,
        maxVisible: 30,
        drawThreshold: 5
      },
      customScalingFunction: function (min,max,total,value) {
        if (max === min) {
          return 0.5;
        }
        else {
          var scale = 1 / (max - min);
          return Math.max(0,(value - min)*scale);
        }
      }
    },
  }
}

network.setOptions(options);

```
- Network - groups（分组）

| 名称 | 类型 | 默认 | 描述     |
|:-------:|:-------------:|:-----:|:-------------------------:|
| useDefaultGroups | boolean | true |如果您的节点具有不在“组”模块中定义的组，则该模块在它所具有的组上循环，为每个未知组分配一个。当所有使用时，它都会回到第一组。通过将此设置为false，默认组将不会在此循环中使用 |
| groups | string | undefined| 如果不是undefined，该节点将属于定义的组。该组的样式信息将应用于此节点。节点特定样式会覆盖组样式。|
```
示例：
var options = {
  groups:{
    useDefaultGroups: true,
    myGroupId:{
      /*node options*/
    }
  }
}
network.setOptions(options);

```
- Network - nodes

| 名称 | 类型 | 默认 | 描述     |
|:-------:|:-------------:|:-----:|:------------------------:|
| borderWidth | number | 1 | 节点边框的宽度 |
| fixed | object or boolean | object | 当为true时，节点不会移动，但是IS是物理模拟的一部分。定义为对象时，可以禁用X或Y方向的移动|
| icon | object | object | 图标，可设置大小、形状、颜色等基本信息|
| image | string | undefined |当形状设置为image或时circularImage，该选项应该是图像的url，若无法找到图像，则使用brokenlmage|
| label | string | undefined |标签是节点中或节点下显示的文本片段，具体取决于形状|
| margin | object or number | 5 | 若指定了数字，则标签的边距将全部设置为该值。当形状被设置为仅用于选项box、cicle、database、icon或text|
| physics | boolean |true |若为false，则该节点不是物理模拟的一部分。除了手动拖动以外，它不会移动。|
| scaling| number| object |用于节点的缩放，使用时size选项会被忽略 |
| shape | string | ellipse |定义节点的外观；内部具有标签： ellipse，circle，database，box，text。标签位于下方：image，circularImage， diamond，dot，star，triangle， triangleDown，hexagon，square和icon。 |
| widthConstraint | string | false| 若指定一个数字，则将该节点的最小和最大宽度设置为该值；可设置标签位置，大小等属性|
| X 与 Y| number | undefined | 这给了一个节点一个初始位置。在使用分层布局时，布局引擎根据视图类型设置x或y位置。另一个值保持不变。使用稳定器时，稳定位置可能与初始位置不同。要将节点锁定到该位置，请使用物理或固定选项。|
```
示例：
var options = {
  nodes:{
    borderWidth: 1,
    fixed: {
      x:false,
      y:false
    },
    icon: {
      face: 'FontAwesome',
      code: undefined,
      size: 50,  //50,
      color:'#2B7CE9'
    },
    image: undefined,
    label: undefined,
    physics: true,
    scaling: {
      min: 10,
      max: 30,
      label: {
        enabled: false,
        min: 14,
        max: 30,
        maxVisible: 30,
        drawThreshold: 5
      },
      customScalingFunction: function (min,max,total,value) {
        if (max === min) {
          return 0.5;
        }
        else {
          let scale = 1 / (max - min);
          return Math.max(0,(value - min)*scale);
        }
      }
    },
    shape: 'ellipse',
    widthConstraint: false,
    x: undefined,
    y: undefined
  }
}

network.setOptions(options);
