{ config, pkgs, ... }:

{
	# Qt theming - use kde platform to read kdeglobals
	qt = {
		enable = true;
		platformTheme = "kde";
	};

	# KDE/Qt color scheme - Catppuccin Mocha Mauve
	environment.etc."xdg/kdeglobals".text = ''
		[ColorEffects:Disabled]
		Color=30,30,46
		ColorAmount=0.3
		ColorEffect=2
		ContrastAmount=0.1
		ContrastEffect=0
		IntensityAmount=-1
		IntensityEffect=0

		[ColorEffects:Inactive]
		ChangeSelectionColor=true
		Color=30,30,46
		ColorAmount=0.5
		ColorEffect=3
		ContrastAmount=0
		ContrastEffect=0
		Enable=true
		IntensityAmount=0
		IntensityEffect=0

		[Colors:Button]
		BackgroundAlternate=203,166,247
		BackgroundNormal=49,50,68
		DecorationFocus=203,166,247
		DecorationHover=49,50,68
		ForegroundActive=250,179,135
		ForegroundInactive=166,173,200
		ForegroundLink=203,166,247
		ForegroundNegative=243,139,168
		ForegroundNeutral=249,226,175
		ForegroundNormal=205,214,244
		ForegroundPositive=166,227,161
		ForegroundVisited=203,166,247

		[Colors:Complementary]
		BackgroundAlternate=17,17,27
		BackgroundNormal=24,24,37
		DecorationFocus=203,166,247
		DecorationHover=49,50,68
		ForegroundActive=250,179,135
		ForegroundInactive=166,173,200
		ForegroundLink=203,166,247
		ForegroundNegative=243,139,168
		ForegroundNeutral=249,226,175
		ForegroundNormal=205,214,244
		ForegroundPositive=166,227,161
		ForegroundVisited=203,166,247

		[Colors:Header]
		BackgroundAlternate=17,17,27
		BackgroundNormal=24,24,37
		DecorationFocus=203,166,247
		DecorationHover=49,50,68
		ForegroundActive=250,179,135
		ForegroundInactive=166,173,200
		ForegroundLink=203,166,247
		ForegroundNegative=243,139,168
		ForegroundNeutral=249,226,175
		ForegroundNormal=205,214,244
		ForegroundPositive=166,227,161
		ForegroundVisited=203,166,247

		[Colors:Selection]
		BackgroundAlternate=203,166,247
		BackgroundNormal=203,166,247
		DecorationFocus=203,166,247
		DecorationHover=49,50,68
		ForegroundActive=250,179,135
		ForegroundInactive=24,24,37
		ForegroundLink=203,166,247
		ForegroundNegative=243,139,168
		ForegroundNeutral=249,226,175
		ForegroundNormal=17,17,27
		ForegroundPositive=166,227,161
		ForegroundVisited=203,166,247

		[Colors:Tooltip]
		BackgroundAlternate=27,25,35
		BackgroundNormal=30,30,46
		DecorationFocus=203,166,247
		DecorationHover=49,50,68
		ForegroundActive=250,179,135
		ForegroundInactive=166,173,200
		ForegroundLink=203,166,247
		ForegroundNegative=243,139,168
		ForegroundNeutral=249,226,175
		ForegroundNormal=205,214,244
		ForegroundPositive=166,227,161
		ForegroundVisited=203,166,247

		[Colors:View]
		BackgroundAlternate=24,24,37
		BackgroundNormal=30,30,46
		DecorationFocus=203,166,247
		DecorationHover=49,50,68
		ForegroundActive=250,179,135
		ForegroundInactive=166,173,200
		ForegroundLink=203,166,247
		ForegroundNegative=243,139,168
		ForegroundNeutral=249,226,175
		ForegroundNormal=205,214,244
		ForegroundPositive=166,227,161
		ForegroundVisited=203,166,247

		[Colors:Window]
		BackgroundAlternate=17,17,27
		BackgroundNormal=24,24,37
		DecorationFocus=203,166,247
		DecorationHover=49,50,68
		ForegroundActive=250,179,135
		ForegroundInactive=166,173,200
		ForegroundLink=203,166,247
		ForegroundNegative=243,139,168
		ForegroundNeutral=249,226,175
		ForegroundNormal=205,214,244
		ForegroundPositive=166,227,161
		ForegroundVisited=203,166,247

		[General]
		ColorScheme=CatppuccinMochaMauve
		Name=Catppuccin Mocha Mauve

		[Icons]
		Theme=Papirus-Dark

		[KDE]
		contrast=4

		[WM]
		activeBackground=30,30,46
		activeBlend=205,214,244
		activeForeground=205,214,244
		inactiveBackground=17,17,27
		inactiveBlend=166,173,200
		inactiveForeground=166,173,200
	'';

	# Fonts - Nerd Fonts for icons
	fonts.packages = with pkgs; [
		nerd-fonts.jetbrains-mono
		nerd-fonts.fira-code
	];

	# Theming packages
	environment.systemPackages = with pkgs; [
		papirus-icon-theme
		adwaita-icon-theme
		hicolor-icon-theme
		bibata-cursors
	];
}
