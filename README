
Geometric Analysis Library for Lua
===

Demonstration images:

Polygon A | Union | Intersection
--- | --- | ---
![Polygon A](demo/polygonA.png?raw=true) | ![Intersection](demo/union.png?raw=true) | ![Union](demo/intersection.png?raw=true)

Polygon B | Subtraction (A-B) | Subtraction (B-A)
--- | --- | ---
![Polygon B](demo/polygonB.png?raw=true) | ![Subtraction](demo/AsubtractB.png?raw=true) | ![Subtraction](demo/BsubtractA.png?raw=true)

Brief
--

This library is intended for geometric analysis of 3D polygon and polyhedron environments.<br/>
Eventually, I will use it in the procedural generation of static game environments.

Library status
---
 - **Spatial representation**
   - **Vertex**
    - **Identity**: Yes (`O(N)` - no octree yet)
   - **Edge**
    - **Identity**: Yes (`O(1)`)
  - **Polygon**
    - **Identity**: Yes (`O(N)`)
    - **Operations**
      - **Point in polygon**: Yes
      - **Intersection**: Yes
      - **Union**: Yes
      - **Subtraction**: Yes (still some edge cases left to examine)
  - **Face**
    - **Identity**: Yes (`O(N)`)
  - **Polyhedron**: No
  - **Solid/Volume**: No

**Lualgebra** - basic numeric and algebraic foundation library
 - **Floating point utilities**: Partial
 - **Big Int via GMP**: Yes (untested)
 - **Exact Real Arithmeatic via IC-Reals**: No
 - **Algebra & Calculus stuff**: No

**Luametry** - polygoaln and polyhedronal geomtric analysis
 - *See above*

**Axiom** - Natural Selection 2 map generatr
 - **Level format reader**: Yes (v9)
 - **Level format writer**: Yes (v9)
 - **Output of luametry primitives**: Partial (vertex, edge, polygon, face)
 - **L-System Engine**: No
 - **Procedural map generation**: No :)

Documentation
--
***Todo***

FAQ
---

**Q: Why are the commit messages so undescriptive?**<br/>
**A:** This project was to help me learn and refactoring occured very often. I didn't want to waste time describing changes when they may disappear next commit. The majority of the commits here to save code just before it was removed, in case I needed it later.

