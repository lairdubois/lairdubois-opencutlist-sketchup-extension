# Frequently Asked Questions

## How can I change the language?

Click the **Preferences** tab on the far bottom right of the maximized OpenCutList window, select the language of your choice. The language of OpenCutList is independent of your SketchUp version, thus in an english SketchUp version you may still select French.

## The dimensions of a component are wrong in the cut list

The dimensions of components are taken from the *bounding box*. Depending on how you draw your component, the bounding box may not be aligned with the component axis. Check out [SketchUp Skill Builder: Group axis and bounding box](https://www.youtube.com/watch?v=2UnzHwAt7mc) to learn about relocating the local axis to align the bounding box with your component.

If you disable the option *Automatic orientation of parts*, the generated cut list will respect the *grain direction* of your component.

## I cannot define material in the plugin

On the **Material** tab of OpenCutList, add a new material and configure its type. Alternatively or if you already have material on your components, you may define the material within SketchUp, then it will appear in the **Materials** tab, where you will have to configure additional information. This information will be used to compute raw dimensions (using the oversize) and select the correct thickness if the material is of type **Solid Wood**.

## Why is my material not configured?

If you have just applied material defined in SketchUp, the plugin lacks the additional information it needs to exactly compute the cut list. Check out the tab **Materials** to enter this information for all material used in your model.

## I have a ~ (tilde) in front of some of the dimensions

This happens when the dimensions are not exact with respect to the precision of your model. See the menu `Tools -> Model Info -> Units`. Enable the *length snapping* and configure it to the same value as *precision* to minimize the effect. However there are situations where this will almost always happen (because you cut a curve or a bevel or because you changed the units of your model after creating your components).

## North America only Problems

In North America, there is a distinction between the **nominal** and the **actual** size of many wood products (rough wood, dimensional lumber, wood panels).
SketchUp and OpenCutList work with **actual dimensions**, therefore you need to enter actual sizes and not nominal sizes.

### My model unit is fractional, do I need to enter nominal or actual dimensions?

For dimensional lumber (softwood), when the nominal size is 2 x 4, the actual size will be at least 1-1/2 x 3-1/2 at 19 % maximum-moisture content.

Here are a few examples from [Archtoolbox](https://www.archtoolbox.com/materials-systems/wood-plastic-composites/dimensional-lumber-sizes-nominal-vs-actual.html).

| Nominal Size (inches)  | Actual Size (inches) | Actual Size (mm)|
| ---------------------- | -------------------- | --------------- |
|     1 x 2              |     3/4 x 1 1/2      |      19 x 38    |
|     1 x 4              |     3/4 x 3 1/2      |      19 x 89    |
|     2 x 4              |     1 1/2 x 3 1/2    |      38 x 89    |
|     2 x 8              |     1 1/2 x 7 1/4    |      38 x 184   |
|     4 x 4              |     3 1/2 x 3 1/2    |      89 x 89    |
|     4 x 8              |     3 1/2 x 7 1/4    |      89 x 184   |

See also [American Softwood Lumber Standard, June 2010](https://www.nist.gov/system/files/documents/2017/06/13/ps20-10.pdf).

### My model unit is fractional, do I need to enter nominal or actual dimensions for my panel?

When you plan to use a panel (OSB, plywood, ...), make sure you note the correct dimensions. Often the hardware store will list the panel with an indication like this:

  Birch Plywood **(Common: 3/4 in. x 2 ft. x 4 ft.; Actual: 0.728 in. x 23.75 in. x 47.75 in.)**

This means that instead of 0.75 in. the panel's thickness is only 0.728 in., not much, but 2 ft. x 4 ft. is missing 1/4 in. You need to take this into account when setting up the trimming size for the panel.
