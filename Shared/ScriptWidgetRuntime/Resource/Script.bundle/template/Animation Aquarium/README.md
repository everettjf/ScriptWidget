# Animation scheduling

This existing example uses public scheduled previews. WidgetKit controls system refresh and can freeze motion; the app/Web preview is not a guarantee of continuous Home Screen animation. Mac, inactive scenes and accessibility modes have static fallbacks. Custom clock periods are signed half-turn durations. Source is preserved; use native date/text components when accurate continuously updating digital time is needed. See docs/public-animations.md in the repository for compatibility details.

# Responsive composition

Each creature has its own fixed-size cell; spaces are not used for positioning. Small widgets use fewer creatures, large and extra-large widgets add a swimming row, and lock-screen accessories use compact static compositions. Swing distances stay small so fish and bubbles remain within the scene. Edit the `Row` symbol arrays to customize it; this dynamic template is edited in Code. Existing user copies are not overwritten.
