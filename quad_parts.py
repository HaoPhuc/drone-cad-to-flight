"""Quadcopter parts for Simscape practice - Fusion 360 script.

Builds a simple 450-size X quadcopter as separate components, then saves one
STEP file per unique part plus quad_layout.csv, which says where every part
sits in the body frame (origin at bottom-plate centre, x forward, y left,
z up, mm). Edit the numbers below and rerun to resize.

Run: Utilities > Add-Ins > Scripts and Add-Ins > + > create a Python script,
Edit it, paste this file over the template, save, then Run.
"""
import adsk.core, adsk.fusion, traceback, math, os

# ---------- dimensions (mm) ----------
MOTOR_SPAN = 450                        # diagonal motor-to-motor distance
PLATE_SIZE, PLATE_T = 120, 2            # square centre plates
ARM_W, ARM_H, ARM_START = 20, 12, 40    # arm starts 40 mm from centre
MOTOR_D, MOTOR_H = 28, 26               # 2212-size motor
SHAFT_D, SHAFT_H = 5, 8
PROP_D, BLADE_W, BLADE_T = 254, 20, 3   # 10-inch prop as a flat bar
HUB_D, HUB_H = 12, 8
BAT_L, BAT_W, BAT_H = 105, 34, 24       # 3S 2200 mAh pack, under the frame
FC_L, FC_W, FC_H = 36, 36, 10           # flight controller on the top plate

ARM_LEN = MOTOR_SPAN / 2 - ARM_START + 15   # arm ends 15 mm past motor centre

# typical masses (g) to use in Simscape; edit to match real parts
MASS = {'BottomPlate': 60, 'TopPlate': 60, 'Arm': 50, 'Motor': 55,
        'Prop': 10, 'Battery': 185, 'FlightController': 40}

# PX4 Quad X order: (arm angle deg, spin: +1 = CCW seen from above, -1 = CW)
MOTORS = [(-45, +1),    # 1 front-right
          (135, +1),    # 2 back-left
          (45, -1),     # 3 front-left
          (-135, -1)]   # 4 back-right


def cm(v):                              # Fusion's API works in cm
    return v / 10.0


def pt(x, y):
    return adsk.core.Point3D.create(cm(x), cm(y), 0)


def extrude(comp, sketch, h, join=False):
    ops = adsk.fusion.FeatureOperations
    op = ops.JoinFeatureOperation if join else ops.NewBodyFeatureOperation
    comp.features.extrudeFeatures.addSimple(
        sketch.profiles.item(0), adsk.core.ValueInput.createByReal(cm(h)), op)


def box(comp, x0, y0, x1, y1, h, join=False):
    sk = comp.sketches.add(comp.xYConstructionPlane)
    sk.sketchCurves.sketchLines.addTwoPointRectangle(pt(x0, y0), pt(x1, y1))
    extrude(comp, sk, h, join)


def cbox(comp, lx, ly, h, join=False):          # box centred on the origin
    box(comp, -lx / 2, -ly / 2, lx / 2, ly / 2, h, join)


def cylinder(comp, d, h, join=False):
    sk = comp.sketches.add(comp.xYConstructionPlane)
    sk.sketchCurves.sketchCircles.addByCenterRadius(pt(0, 0), cm(d / 2))
    extrude(comp, sk, h, join)


def placement(x=0, y=0, z=0, rotz=0):
    m = adsk.core.Matrix3D.create()
    m.setToRotation(math.radians(rotz), adsk.core.Vector3D.create(0, 0, 1),
                    adsk.core.Point3D.create(0, 0, 0))
    m.translation = adsk.core.Vector3D.create(cm(x), cm(y), cm(z))
    return m


# each part is modelled at its own origin; that origin is its Simscape frame
def build_arm(c):                               # along local +x
    box(c, 0, -ARM_W / 2, ARM_LEN, ARM_W / 2, ARM_H)


def build_motor(c):                             # origin = centre of motor base
    cylinder(c, MOTOR_D, MOTOR_H)
    cylinder(c, SHAFT_D, MOTOR_H + SHAFT_H, join=True)


def build_prop(c):                              # origin = bottom of hub, spin axis = z
    cbox(c, PROP_D, BLADE_W, BLADE_T)
    cylinder(c, HUB_D, HUB_H, join=True)


def run(context):
    ui = None
    try:
        app = adsk.core.Application.get()
        ui = app.userInterface

        dlg = ui.createFolderDialog()
        dlg.title = 'Folder for the STEP files'
        if dlg.showDialog() != adsk.core.DialogResults.DialogOK:
            return
        folder = dlg.folder

        app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
        design = adsk.fusion.Design.cast(app.activeProduct)
        design.designType = adsk.fusion.DesignTypes.ParametricDesignType
        occs = design.rootComponent.occurrences

        parts, rows = {}, []

        def add(label, name, build, x=0, y=0, z=0, rotz=0, spin=0):
            m = placement(x, y, z, rotz)
            if name in parts:                   # another copy of the same part
                occs.addExistingComponent(parts[name], m)
            else:
                comp = occs.addNewComponent(m).component
                comp.name = name
                build(comp)
                parts[name] = comp
            rows.append((label, name, x, y, z, rotz, spin))

        R = MOTOR_SPAN / 2
        z_arm_top = PLATE_T + ARM_H             # top plate and motor bases sit here

        add('BottomPlate', 'BottomPlate', lambda c: cbox(c, PLATE_SIZE, PLATE_SIZE, PLATE_T))
        add('TopPlate', 'TopPlate', lambda c: cbox(c, PLATE_SIZE, PLATE_SIZE, PLATE_T), z=z_arm_top)
        add('FlightController', 'FlightController', lambda c: cbox(c, FC_L, FC_W, FC_H),
            z=z_arm_top + PLATE_T)
        add('Battery', 'Battery', lambda c: cbox(c, BAT_L, BAT_W, BAT_H), z=-BAT_H)

        for i, (ang, spin) in enumerate(MOTORS, start=1):
            ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
            add(f'Arm{i}', 'Arm', build_arm, ARM_START * ca, ARM_START * sa, PLATE_T, ang)
            add(f'Motor{i}', 'Motor', build_motor, R * ca, R * sa, z_arm_top)
            add(f'Prop{i}', 'Prop', build_prop, R * ca, R * sa,
                z_arm_top + MOTOR_H + SHAFT_H, spin=spin)

        em = design.exportManager
        for name, comp in parts.items():
            em.execute(em.createSTEPExportOptions(os.path.join(folder, name + '.step'), comp))

        with open(os.path.join(folder, 'quad_layout.csv'), 'w') as f:
            f.write('label,step_file,x_mm,y_mm,z_mm,rotz_deg,mass_g,spin\n')
            for label, name, x, y, z, rotz, spin in rows:
                f.write(f'{label},{name}.step,{x:.2f},{y:.2f},{z:.2f},{rotz},{MASS[name]},{spin}\n')

        app.activeViewport.fit()
        total = sum(MASS[r[1]] for r in rows)
        ui.messageBox(f'Saved {len(parts)} STEP files and quad_layout.csv to\n{folder}\n\n'
                      f'Total mass: {total} g')
    except:
        if ui:
            ui.messageBox('Failed:\n' + traceback.format_exc())
