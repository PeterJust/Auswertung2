function Out = movingaverage(inputt, varargin)
% Moving Average Algorithmus ähnlich movmean, der aber Anfang und Ende vernachlässigt. D.h. wenn b die Mittelungsbreite ist, startet der Algoritmus erst ab Punkt b+1 und endet b Punkte vor Ende.
% INPUT: zu mittelnde Daten, optionale Parameter: Mittelungsbreite, Mittelungsmethode -> z.B. 'mittelungsbreite', 100, 'methode', 2
% OUTPUT: Gemittelte Daten mit Nullen am Anfang und Ende in der länge der Mittelungsbreite b.
%
% Version: 1.0
% Datum: 2017-04-06
% Autor: Peter Jüstel
% Lizenz: CC-BY-SA 4.0 (Feel free, but attribute the author, and share remixes under similar terms)
% https://creativecommons.org/licenses/by-sa/4.0/
% https://creativecommons.org/licenses/by-sa/4.0/legalcode

%%%% TODO
% Bei gewichtetem Mittelwert ist die Konfiguration noch hard-coded. -> dynamisch konfigurierbar!

%%%% config
mittelungsbreite_default = 1;		% Defaults
methode_default = 1;


%%%% parse input

aufteiler = inputParser;	% erstellt eine Instanz/ ein Objekt aus der Klasse inputParser, um den Input aufzubereiten. für Beschreibung siehe kalibrieren.m
addParameter(aufteiler, 'mittelungsbreite', mittelungsbreite_default)
addParameter(aufteiler, 'methode', methode_default)

parse(aufteiler, varargin{:})	% Die Inputargumente nach den Definitionen bearbeitet. -> erkennt ob optionale Parameter genutzt wurden, und wenn nicht, läd es die defaults.

% Resultate auslesen.
b = aufteiler.Results.mittelungsbreite;
methode = aufteiler.Results.methode;

% sanity check
if length(inputt) < 2*b+1
	error(['Daten sind kürzer als Mittelungsbreite ', num2str(2*b+1), '. Mindestlänge ist 3 Datenpunkte.'])
end



%%%% exec
len = length(inputt);
Tr = zeros(len,1);
if methode == 1
	for ii = b+1:(len-b)
		Tr(ii) = sum( inputt(ii-b:ii+b) ) / (2*b+1);	% Zentraler arithmetischer Mittelwert an der stelle ii, mit einer Mittelungsbreite von 2*b 
	end
	
elseif methode == 2
	for ii = b+1:(len-b)
		Tr(ii) = median(inputt(ii-b:ii+b));			% median statt arithmetischer Mittelwert
	end
	
elseif methode == 3
	% gewichteter Mittelwert (EXPERIMENTELL!)
	b = 50;				% bestimmt, wie weit nach links und rechts noch gesehen wird. Bestimmt, wie gut "gräben" überbrückt werden (?). Standard=50
	omega = 20;			% bestimmt, wie weit der Einfluss von Sprüngen in y-richtung reicht. Größen außerhalb dieses Radius werden mehr oder weniger ignoriert. Standard=20
	iterationen = 4;	% bestimmt, wie glatt die kurve am Ende ist (und wie lang die Rechnung dauert). Standard=4
	daempfung = 2;		% agressivität der Dämpfung. Bestimmt, wie scharf die Kanten sind. Standard=2
	
	for jj = 1:iterationen
		for ii = b+1:(len-b)
			y = abs( inputt(ii-b:ii+b)-inputt(ii) );	% Transformation in Differenzenraum
			G = 1./(1+ (y/omega).^daempfung);						% Gewichte in Form einer PT Übertragungsfunktion mit cutoff-frequenz bei omega
			Tr(ii) = sum( inputt(ii-b:ii+b) .*G ) / sum(G);	% Gewichteter zentraler arithmetischer Mittelwert an der stelle ii, mit einer Mittelungsbreite von 2*b 
		end
		inputt = Tr;
	end
	disp('ACHTUNG: Der gewichtete Mittelwert ist eine experimentelle Methode!')
end

Out = Tr;
end