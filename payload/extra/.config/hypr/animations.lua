-- Animations
hl.config({ animations = { enabled = true } })

-- Custom Bezier curve
hl.curve("myBezier", {
    type = "bezier",
    points = {
        { 0.10, 0.9 },
        { 0.1, 1.05 }
    }
})

-- Window animations: 500ms
hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 5,
    bezier = "myBezier",
    style = "slide"
})

hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 5,
    bezier = "myBezier",
    style = "slide"
})

-- Border animation: 1000ms
hl.animation({
    leaf = "border",
    enabled = true,
    speed = 10,
    bezier = "default"
})

-- Fade animation: 700ms
hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 7,
    bezier = "default"
})

-- Workspace animation: 600ms
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 6,
    bezier = "default"
})