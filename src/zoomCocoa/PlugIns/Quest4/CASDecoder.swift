//
//  CASDecoder.swift
//  ZoomCocoa
//
//  Created by C.W. Betts on 4/4/25.
//

import Foundation

private let compilation_tokens =
["", "game", "procedure", "room", "object", "character", "text", "selection",
 "define", "end", "", "asl-version", "game", "version", "author", "copyright",
 "info", "start", "possitems", "startitems", "prefix", "look", "out", "gender",
 "speak", "take", "alias", "place", "east", "north", "west", "south", "give",
 "hideobject", "hidechar", "showobject", "showchar", "collectable",
 "collecatbles", "command", "use", "hidden", "script", "font", "default",
 "fontname", "fontsize", "startscript", "nointro", "indescription",
 "description", "function", "setvar", "for", "error", "synonyms", "beforeturn",
 "afterturn", "invisible", "nodebug", "suffix", "startin", "northeast",
 "northwest", "southeast", "southwest", "items", "examine", "detail", "drop",
 "everywhere", "nowhere", "on", "anything", "article", "gain", "properties",
 "type", "action", "displaytype", "override", "enabled", "disabled",
 "variable", "value", "display", "nozero", "onchange", "timer", "alt", "lib",
 "up", "down", "gametype", "singleplayer", "multiplayer", "", "", "", "", "",
 "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
 "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
 "", "", "", "", "", "", "", "", "", "", "", "do", "if", "got", "then", "else",
 "has", "say", "playwav", "lose", "msg", "not", "playerlose", "playerwin",
 "ask", "goto", "set", "show", "choice", "choose", "is", "setstring",
 "displaytext", "exec", "pause", "clear", "debug", "enter", "movechar",
 "moveobject", "revealchar", "revealobject", "concealchar", "concealobject",
 "mailto", "and", "or", "outputoff", "outputon", "here", "playmidi", "drop",
 "helpmsg", "helpdisplaytext", "helpclear", "helpclose", "hide", "show",
 "move", "conceal", "reveal", "numeric", "string", "collectable", "property",
 "create", "exit", "doaction", "close", "each", "in", "repeat", "while",
 "until", "timeron", "timeroff", "stop", "panes", "on", "off", "return",
 "playmod", "modvolume", "clone", "shellexe", "background", "foreground",
 "wait", "picture", "nospeak", "animate", "persist", "inc", "dec", "flag",
 "dontprocess", "destroy", "beforesave", "onload", "", "", "", "", "", "",
 "", "", "", "", "", "", "", "", "", "", "", ""];

func CASDecompile(_ dat: Data) -> [String] {
	var cur_line = ""
	var tok: String?
	var expect_text = 0
	var obfus = 0
	var rv: [String] = []
	
	for ch in dat[8...] {
		if obfus == 1 && ch == 0 {
			cur_line.append("> ")
			obfus = 0
		} else if obfus == 1 {
			cur_line.append(String(format: "%C", unichar(255 &- ch)))
		} else if obfus == 2 && ch == 254 {
			obfus = 0
			cur_line.append(" ")
		} else if obfus == 2 {
			cur_line.append(String(format: "%C", unichar(ch)))
		} else if expect_text == 2 {
			if ch == 253 {
				expect_text = 0
				rv.append(cur_line)
				cur_line.removeAll()
			} else if ch == 0 {
				rv.append(cur_line)
				cur_line.removeAll()
			} else {
				cur_line.append(String(format: "%C", unichar(255 &- ch)))
			}
		} else if obfus == 0 && ch == 10 {
			cur_line.append("<")
			obfus = 1
		} else if obfus == 0 && ch == 254 {
			obfus = 2
		} else if ch == 255 {
			if expect_text == 1 {
				expect_text = 2
			}
			rv.append(cur_line)
			cur_line.removeAll()
		} else {
			tok = compilation_tokens[Int(ch)];
			if (tok == "text" || tok == "synonyms" || tok == "type") &&
				cur_line == "define " {
				expect_text = 1
			}
			cur_line.append(tok! + " ")
		}
	}
	rv.append(cur_line)
	
	return rv
}
