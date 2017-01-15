# Frequently Asked Questions

## The dimensions of a component are wrong in the cut list

The dimensions of components are taken from the *bounding box*. Depending on how you draw your component, the bounding box may not be aligned with the component axis. Check out [SketchUp Skill Builder: Group axis and bounding box](https://www.youtube.com/watch?v=2UnzHwAt7mc) to learn about relocating the local axis to align the bounding box with your component.

If you disable the option *Automatic orientation of parts*, the generated cut list will respect the *grain direction* of your component.

## I cannot define material in the plugin

The material needs to be defined within SketchUp, then it will appear in the **Materials** tab, where you may configure additional information. This information will be used to compute raw dimensions (using the oversize) and select the correct thickness if the material is of type **Solid Wood**.

## Why is my material not configured?

If you have just applied material defined in SketchUp, the plugin lacks the additional information it needs to exactly compute the cut list. Check out the tab **Materials** to enter this information for all material used in your model.

## I have a ~ (tilde) in front of some of the dimensions

This happens when the dimensions are not exact with respect to the precision of your model. See the menu `Tools -> Model Info -> Units`. Enable the *length snapping* and configure it to the same value as *precision* to minimize the effect. However there are situations where this will almost always happen (because you cut a curve or a bevel or because you changed the units of your model after creating your components).