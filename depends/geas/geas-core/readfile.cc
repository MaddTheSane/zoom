/***************************************************************************
 *                                                                         *
 * Copyright (C) 2006 by Mark J. Tilford                                   *
 *                                                                         *
 * This file is part of Geas.                                              *
 *                                                                         *
 * Geas is free software; you can redistribute it and/or modify            *
 * it under the terms of the GNU General Public License as published by    *
 * the Free Software Foundation; either version 2 of the License, or       *
 * (at your option) any later version.                                     *
 *                                                                         *
 * Geas is distributed in the hope that it will be useful,                 *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of          *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           *
 * GNU General Public License for more details.                            *
 *                                                                         *
 * You should have received a copy of the GNU General Public License       *
 * along with Geas; if not, write to the Free Software                     *
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *                                                                         *
 ***************************************************************************/

#include <vector>
#include <map>
#include <string>
#include <iostream>
//#include <fstream>
#include <sstream>
#include "readfile.hh"
#include "geas-util.hh"
#include "reserved_words.hh"
#include "GeasRunner.hh"
#include "general.hh"

using namespace std;

//string readfile (string s);

string next_token (const string &full, std::string::size_type &tok_start, std::string::size_type &tok_end, bool cvt_paren)
{
  tok_start = tok_end;
  while (tok_start < full.length() && isspace (full[tok_start]))
    ++ tok_start;
  if (tok_start >= full.length())
    {
      tok_start = tok_end = full.length();
      //tok_start = tok_end = string::npos;
      return "";
    }
  tok_end = tok_start + 1;
  if (full[tok_start] == '{' || full[tok_start] == '}')
    /* brace is a token by itself */;
  else if (full[tok_start] == '<')
    {
      while (tok_end < full.length() && full [tok_end] != '>')
	++ tok_end;
      if (full[tok_end] == '>')
	++ tok_end;
    }
  else if (cvt_paren && full[tok_start] == '(')
    {
      uint depth = 1;
      /*
      while (tok_end < full.length() && full [tok_end] != ')')
	++ tok_end;
      if (full[tok_end] == ')')
	++ tok_end;
      */
      do {
	if (full[tok_end] == '(')
	  ++ depth;
	else if (full[tok_end] == ')')
	  -- depth;
	++ tok_end;
      } while (tok_end < full.length() && depth > 0);
    }
  else
    while (tok_end < full.length() && !isspace (full[tok_end]))
      ++ tok_end;
  return full.substr (tok_start, tok_end - tok_start);
}

string first_token (const string &s, std::string::size_type &t_start, std::string::size_type &t_end)
{
  t_end = 0;
  return next_token (s, t_start, t_end);
}

string nth_token (const string &s, int n)
{
  std::string::size_type x1, x2 = 0;
  string rv;
  do
    rv = next_token (s, x1, x2);
  while (-- n > 0);
  return rv;
}

string get_token (const string &s, bool cvt_paren)
{
  std::string::size_type x1, x2 = 0;
  return next_token (s, x1, x2, cvt_paren);
}

bool find_token (const string &s, const string &tok, std::string::size_type &tok_start, std::string::size_type &tok_end, bool cvt_paren)
{
  std::string::size_type copy_start, copy_end;
  copy_end = tok_end;

  do
    {
      string tmp = next_token (s, copy_start, copy_end, cvt_paren);
      if (tmp == tok)
	{
	  tok_start = copy_start;
	  tok_end = copy_end;
	  return true;
	}
    }
  while (copy_end < s.size());

  return false;
}

static bool is_define (const string &s)
{
  return get_token(s) == "define";
}

static bool is_define (const string &s, const string &t)
{
  std::string::size_type t1, t2 = 0;
  return next_token (s, t1, t2) == "define" &&
    next_token (s, t1, t2) == t;
}

static bool is_start_textmode (const string &s)
{
  std::string::size_type start_char, end_char = 0;
  if (next_token (s, start_char, end_char) != "define") return false;
  string tmp = next_token (s, start_char, end_char);
  // SENSITIVE?
  return tmp == "text" || tmp == "synonyms";
}

static bool is_end_define (const string &s)
{
  std::string::size_type start_char, end_char = 0;
  // SENSITIVE?
  return (next_token (s, start_char, end_char) == "end" &&
	  next_token (s, start_char, end_char) == "define");
}



static vector<string> split_lines (const string &data);

/*
GeasBlock::GeasBlock (const vector<string> &in_data, string in_parent, 
		      uint i, bool recurse)
{
  //cerr << "GeasBlock (...) processing line #" << i << ": " << in_data[i] << endl;
  parent = in_parent;
  uint t1, t2; 
  first_token (in_data[i], t1, t2); // "define"
  blocktype = next_token (in_data[i], t1, t2); // "object", or the like
  name = next_token (in_data[i], t1, t2); // "<itemname>", or the like
  if (is_param (name))
    name = param_contents(name);
  else if (name != "")
    throw string ("Expected parameter; " + name + " found instead.");
  i ++;
  uint depth = 1;
  while (i < in_data.size() && depth > 0)
    {
      if (recurse && is_define (in_data[i]))
	++ depth;
      else if (is_end_define (in_data[i]))
	-- depth;
      else if (depth == 1)
	data.push_back (in_data[i]);
      ++ i;
    }
}
*/

/*
template <class T> ostream &operator << (ostream &o, vector<T> v)
{
  o << "{ '";
  for (uint i = 0; i < v.size(); i ++)
    {
      o << v[i];
      if (i + 1 < v.size())
	o << "', '";
    }
  o << "' }";
  return o;
}
*/

static reserved_words dir_tag_property ("north", "south", "east", "west", "northwest", "northeast", "southeast", "southwest", "up", "down", "out", (char *) NULL);

void GeasFile::read_into (const vector<string> &in_data,
			  const string &in_parent, uint cur_line, bool recurse,
			  const reserved_words &props, 
			  const reserved_words &actions)
{
  //cerr << "r_i: Reading in from" << cur_line << ": " << in_data[cur_line] << endl;
  //output.push_back (GeasBlock());
  //GeasBlock &out_block = output[output.size() - 1];
  size_t blocknum = blocks.size();
  blocks.push_back (GeasBlock());
  GeasBlock &out_block = blocks[blocknum];

  vector<string> &out_data = out_block.data;
  out_block.parent = in_parent;
  std::string::size_type t1, t2;
  string line = in_data[cur_line];
  // SENSITIVE?
  string token = first_token (line, t1, t2);
  assert (token == "define");
  string blocktype = out_block.blocktype = next_token (line, t1, t2); // "object", or the like
  //cerr << "r_i: Pushing back block of type " << blocktype << "\n";
  type_indecies[blocktype].push_back (blocknum);
  string name = next_token (line, t1, t2); // "<itemname>", or the like

  // SENSITIVE?
  if (blocktype == "game")
    {
      out_block.name = "game";
      out_data.push_back ("game name " + name);
    }
  else if (is_param(name))
    out_block.name = param_contents(name);
  else if (name != "")
    throw string ("Expected parameter; " + name + " found instead.");
  //out_block.lname = lcase (out_block.nname);

  // apparently not all block types are unique ... TODO which?
  // SENSITIVE?
  if (blocktype == "room" || blocktype == "object" || blocktype == "game")
    register_block (out_block.name, blocktype);
  //register_block (out_block.lname, blocktype);

  // SENSITIVE?
  if (blocktype == "room" && find_by_name ("type", "defaultroom"))
    out_data.push_back ("type <defaultroom>");
  // SENSITIVE?
  if (blocktype == "object" && find_by_name ("type", "default"))
    out_data.push_back ("type <default>");
      
  cur_line ++;
  uint depth = 1;
  while (cur_line < in_data.size() && depth > 0)
    {
      line = in_data[cur_line];
      if (recurse && is_define (line))
	++ depth;
      else if (is_end_define (in_data[cur_line]))
	-- depth;
      else if (depth == 1)
	{
	  //cerr << "r_i: Processing line #" << cur_line << ": " << line << endl;
	  //string dup_data = "";
	  string tok = first_token (line, t1, t2);
	  string rest = next_token (line, t1, t2);

	  //cerr << "r_i: tok == '" << tok << "', props[tok] == " << props[tok]
	  //     << ", actions[tok] == " << actions[tok] << "\n";

	  if (props[tok] && dir_tag_property[tok])
	    out_data.push_back (line);

	  if (props[tok] && rest == "")
	    {
	      //cerr << "r_i: Handling as props <tok>\n";
	      line = "properties <" + tok + ">";
	    }
	  else if (props[tok] && is_param(rest))
	    {
	      //cerr << "r_i: Handling as props <tok = ...>\n";
	      line = "properties <" + tok + "=" + param_contents(rest) + ">";
	    }
	  else if (actions[tok] && 
		   (tok == "use" || tok == "give" || !is_param(rest)))
	    {
	      //cerr << "r_i: Handling as action '" << tok << "'\n";
	      // SENSITIVE?
	      if (tok == "use")
		{
		  //cerr << "r_i: ********** Use line: <" + line + "> ---> ";
		  string lhs = "action <use ";
		  // SENSITIVE?
		  if (rest == "on")
		    {
		      rest = next_token (line, t1, t2);
		      string rhs = line.substr (t2);
		      // SENSITIVE?
		      if (rest == "anything")
			line = lhs + "on anything> " + rhs;
		      // SENSITIVE?
		      else if (is_param (rest))
			line = lhs + "on " + param_contents(rest) + "> " + rhs;
		      else
			{
			  //cerr << "r_i: Error handling '" << line << "'" << endl;
			  line = "ERROR: " + line;
			}
		    }
		  // SENSITIVE?
		  else if (rest == "anything")
		    line = lhs + "anything> " + line.substr (t2);
		  else if (is_param(rest))
		    line = lhs + param_contents(rest) +"> " +line.substr(t2);
		  else
		    line = "action <use> " + line.substr (t1);
		  //cerr << "r_i: <" << line << ">\n";
		}
	      // SENSITIVE?
	      else if (tok == "give")
		{ 
		  string lhs = "action <give ";
		  // SENSITIVE?
		  if (rest == "to")
		    {
		      rest = next_token (line, t1, t2);
		      string rhs = line.substr (t2);
		      // SENSITIVE?
		      if (rest == "anything")
			line = lhs + "to anything> " + rhs;
		      else if (is_param(rest))
			line = lhs + "to " + param_contents(rest) + "> " + rhs;
		      else
			{
			  cerr << "Error handling '" << line << "'" << endl;
			  line = "ERROR: " + line;
			}
		    }
		  // SENSITIVE?
		  else if (rest == "anything")
		    line = lhs + "anything> " + line.substr (t2);
		  else if (is_param(rest))
		    line = lhs + param_contents(rest) +"> " +line.substr(t2);
		  else
		    line = "action <give> " + line.substr (t1);
		}
	      else		
		line = "action <" + tok + "> " + line.substr (t1);
	    }
	  //else
	  //  cerr << "Handling as ordinary line\n";

	  // recalculating tok because it might have changed
	  /* TODO: Make sure this only happens on object-type blocks */
	  tok = first_token (line, t1, t2);
	  // SENSITIVE?
	  if (tok == "properties")
	    {
	      rest = next_token (line, t1, t2);
	      if (is_param (rest))
		{
		  vstring items = split_param (param_contents (rest));
		  for (uint i = 0; i < items.size(); i ++)
		    out_data.push_back ("properties <" + 
					static_eval(items[i]) + ">");
		}
	      else
		out_data.push_back ("ERROR " + line);
	    }
	  else
	    out_data.push_back(line);

	  //if (dup_data != "")
	  //  out_data.push_back (dup_data);
	}
      cur_line ++;
    }
}

GeasFile::GeasFile (const vector<string> &v, GeasInterface *_gi) : gi(_gi)
{
  uint depth = 0;

  string parentname, parenttype;

  static string pass_names[] = 
    {"game", "type", "room", "variable", "object", "procedure", 
     "function", "selection", "synonyms", "text", "timer"};

  reserved_words recursive_passes ("game", "room", (char*) NULL),
    object_passes ("game", "room", "objects", (char*) NULL);
  

  //vector <GeasBlock> outv;
  for (uint pass = 0; pass < sizeof (pass_names) / sizeof (*pass_names);
       pass ++)
    {
      string this_pass = pass_names[pass];
      bool recursive = recursive_passes[this_pass];
      //bool is_object = object_passes[this_pass];

      reserved_words actions ((char *) NULL), props ((char *) NULL);
      // SENSITIVE?
      if (this_pass == "room")
	{
	  props = reserved_words ("look", "alias", "prefix", "indescription", "description", "north", "south", "east", "west", "northeast", "northwest", "southeast", "southwest", "out", "up", "down", (char *) NULL);
	  actions = reserved_words ("description", "script", "north", "south", "east", "west", "northeast", "northwest", "southeast", "southwest", "out", "up", "down", (char *) NULL);
	}
      // SENSITIVE?
      else if (this_pass == "object")
	{
	  props = reserved_words ("look", "examine", "speak", "take", "alias", "prefix", "suffix", "detail", "displaytype", "gender", "article", "hidden", "invisible", (char *) NULL);
	  actions = reserved_words ("look", "examine", "speak", "take", "gain", "lose", "use", "give", (char *) NULL);
	}
	  
      depth = 0;
      for (uint i = 0; i < v.size(); i ++)
	if (is_define(v[i]))
	  {
	    ++ depth;
	    string blocktype = nth_token (v[i], 2);
	    if (depth == 1)
	      {
		parenttype = blocktype;
		parentname = nth_token (v[i], 3);
		
		// SENSITIVE?
		if (blocktype == this_pass)
		  read_into (v, "", i, recursive, props, actions);
	      }
	    else if (depth == 2 && blocktype == this_pass)
	      {
		// SENSITIVE?
		if (this_pass == "object" && parenttype == "room")
		  read_into (v, parentname, i, false, props, actions);
		// SENSITIVE?
		else if (this_pass == "variable" && parenttype == "game")
		  read_into (v, "", i, false, props, actions);
	      }
	  }
	else if (is_end_define (v[i]))
	  -- depth;
    }

}

static bool decompile (const string &data, vector<string> &rv);

static bool preprocess (vector<string> v, const string &fname, vector<string> &rv, GeasInterface *gi);

GeasFile read_geas_file (GeasInterface *gi, const string &filename)
{
  //return GeasFile (split_lines(gi->get_file(s)), gi);
  string file_contents = gi->get_file (filename);

  if (file_contents == "")
    return GeasFile();

  vector<string> data;
  bool success;

  cerr << "Header is '" << file_contents.substr (0, 7) << "'.\n";
  if (file_contents.size() > 8 && file_contents.substr (0, 7) == "QCGF002")
    {
      cerr << "Decompiling\n";
      success = decompile (file_contents, data);
    }
  else
    {
      cerr << "Preprocessing\n";
      success = preprocess (split_lines (file_contents), filename, data, gi);
    }

  cerr << "File load was " << (success ? "success" : "failure") << endl;

  if (success)
    return GeasFile (data, gi);
  
  gi->debug_print ("Unable to read file " + filename);
  return GeasFile();
}


ostream &operator << (ostream &o, const GeasBlock &gb)
{
  //o << "Block " << gb.blocktype << " '" << gb.nname;
  o << "Block " << gb.blocktype << " '" << gb.name;
  if (gb.parent != "")
    o << "' and parent '" << gb.parent;
  o << "'\n";
  for (uint i = 0; i < gb.data.size(); i ++)
    o << "    " << gb.data[i] << "\n";
  o << "\n";
  return o;
}

void print_vblock (ostream &o, string blockname, const vector<GeasBlock> &blocks)
{
  o << blockname << ":\n";
  for (uint i = 0; i < blocks.size(); i ++)
    o << "  " << blocks[i] << "\n";
  o << "\n";
}

ostream &operator << (ostream &o, const GeasFile &gf)
{
  /*
  o << "Geas File\nThing-type blocks:\n";
  for (uint i = 0; i < gf.things.size(); i ++)
    o << gf.things[i];
  o << "\nOther-type blocks:\n";
  for (uint i = 0; i < gf.others.size(); i ++)
    o << gf.others[i];
  */
  o << "Geas File\n";
  for (map<string, vector<size_t> >::const_iterator i = gf.type_indecies.begin();
       i != gf.type_indecies.end(); i ++)
    {
      o << "Blocks of type " << (*i).first << "\n";
      for (uint j = 0; j < (*i).second.size(); j ++)
	o << gf.blocks[(*i).second[j]];
      o << "\n";
    }

  /*
  o << "Geas File\n";
  print_vblock (o, "game",        gf.game);
  print_vblock (o, "rooms",       gf.rooms);
  print_vblock (o, "objects",     gf.objects);
  print_vblock (o, "text blocks", gf.textblocks);
  print_vblock (o, "functions",   gf.functions);
  print_vblock (o, "procedures",  gf.procedures);
  print_vblock (o, "types",       gf.types);
  print_vblock (o, "synonyms",    gf.synonyms);
  print_vblock (o, "timers",      gf.timers);
  print_vblock (o, "variables",   gf.variables);
  print_vblock (o, "choices",     gf.choices);
  */
  o << endl;
  return o;
}





const string compilation_tokens[256] = 
{"", "game", "procedure", "room", "object", "character", "text", "selection", 
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
 "", "", "", "", "", "", "", "", "", "", "", "" };


bool decompile (const string &s, vector<string> &rv)
{
  string cur_line, tok;
  uint expect_text = 0, obfus = 0;
  unsigned char ch;
  
  for (uint i = 8; i < s.length(); i ++)
    {
      ch = s[i];
      if (obfus == 1 && ch == 0)
	{
	  cur_line += "> ";
	  obfus = 0;
	}
      else if (obfus == 1)
	cur_line += char (255 - ch);
      else if (obfus == 2 && ch == 254)
	{
	  obfus = 0;
	  cur_line += " ";
	}
      else if (obfus == 2)
	cur_line += ch;
      else if (expect_text == 2)
	{
	  if (ch == 253)
	    {
	      expect_text = 0;
	      rv.push_back (cur_line);
	      cur_line = "";
	    }
	  else if (ch == 0)
	    {
	      rv.push_back (cur_line);
	      cur_line = "";
	    }
	  else 
	    cur_line += char (255 - ch);
	}
      else if (obfus == 0 && ch == 10)
	{
	  cur_line += "<";
	  obfus = 1;
	}
      else if (obfus == 0 && ch == 254)
	obfus = 2;
      else if (ch == 255)
	{
	  if (expect_text == 1)
	    expect_text = 2;
	  rv.push_back (cur_line);
	  cur_line = "";
	}
      else
	{
	  tok = compilation_tokens[ch];
	  if ((tok == "text" || tok == "synonyms" || tok == "type") && 
	      cur_line == "define ")
	    expect_text = 1;
	  cur_line += tok + " ";
	}
    }
  rv.push_back (cur_line);

  for (uint i = 0; i < rv.size(); i ++)
    cerr << "rv[" << i << "]: " << rv[i] << "\n";

  return true;
}








vector<string> tokenize (const string &s)
{
  std::string::size_type tok_start, tok_end;
  string tok;
  vector<string> rv;
  tok_end = 0;
  while (tok_end + 1 <= s.length())
    rv.push_back (next_token (s, tok_start, tok_end));
  return rv;
}

string string_int (int i) 
{ 
  ostringstream o;
  o << i;
  return o.str();
}

string string_int (uint i)
{
  ostringstream o;
  o << i;
  return o.str();
}

string string_int (size_t i)
{
  ostringstream o;
  o << i;
  return o.str();
}

void report_error (const string &s)
{
  //cerr << s << endl; 
  cerr << s << endl; 
  throw s;
}

vector<string> split_lines (const string &data)
{
  vector <string> rv;
  string tmp;
  uint i = 0;
  while (i < data.length())
    {
      //cerr << "data[" << i << "] == " << int(data[i]) << '\n';

      if (data[i] == '\n' || data[i] == '\r')
	{
	  /*
	  if (data[i] == '\n' && i < data.length() && data[i+1] == '\r')
 	    ++ i;
	  */
	  if (tmp.size() > 0 && tmp[tmp.size() - 1] == '_')
	    {
	      //cerr << "Line with trailing underscores: " << tmp << '\n';
	      tmp.erase (tmp.size() - 1);
	      if (tmp[tmp.size() - 1] == '_')
		tmp.erase (tmp.size() - 1);
	      if (i < data.length() && data[i] == '\r' && data[i+1] == '\n')
		++ i;
	      ++ i;
	      //cerr << "   WSK: data[" << i<< "] == " << int(data[i]) << '\n';
	      while (i < data.length() && data[i] != '\r' && 
		     data[i] != '\n' && isspace(data[i]))
		{
		  //cerr << "   WS: data[" << i<< "] = " << int(data[i]) << '\n';
		  ++ i;
		}
	      //cerr << "   WS: data[" << i<< "] == " << int(data[i]) << '\n';
	      -- i;
	    }
	  else
	    {
	      //cerr << "Pushing back {<{" << tmp << "}>}\n";
	      rv.push_back (tmp);
	      tmp = "";
	      if (i < data.length() && data[i] == '\r' && data[i+1] == '\n')
		++ i;
	    }
	}
      else
	tmp += data[i];
      ++ i;
    }
  if (tmp != "")
    rv.push_back (tmp);
  return rv;
}

void show_tokenize (string s)
{
  //cerr << "s_t: Tokenizing '" << s << "' --> " << tokenize(s) << endl;
}

void say_push (const vector<string> &v)
{
  //cerr << "s_p: Pushing '" << v[v.size() - 1] << "'" << endl;
}
	  




//enum trim_modes { TRIM_SPACES, TRIM_UNDERSCORE, TRIM_BRACE };

//string trim (string s, trim_modes trim_mode = TRIM_SPACES)
string trim (const string &s, trim_modes trim_mode)
{
  std::string::size_type i, j;
  /*
  cerr << "Trimming (" << s << "): [";
  for (i = 0; i < s.length(); i ++)
    cerr << int (s[i]) << "(" << s[i] << "), ";
  cerr << "]\n";
  */
  for (i = 0; i < s.length() && isspace (s[i]); i ++)
    ;
  if (i == s.length()) return "";
  if ((trim_mode == TRIM_UNDERSCORE   &&  s[i] == '_') ||
      (trim_mode == TRIM_BRACE        &&  s[i] == '['))
    ++ i;
  if (i == s.length()) return "";
  for (j = s.length() - 1; isspace (s[j]); j --)
    ;
  if ((trim_mode == TRIM_UNDERSCORE && i < s.length() && s[j] == '_') ||
      (trim_mode == TRIM_BRACE && i < s.length()      && s[j] == ']'))
    -- j;
  return s.substr (i, j-i+1);
}

/* bool is_balanced (string)
 * 
 * Decides whether the string has balanced braces (and needn't be deinlined)
 * - Track the nesting depth, starting at first lbrace to end of line
 * - If it is ever at depth 0 before the end, it's balanced
 * - Otherwise, it's unbalanced
 */
bool is_balanced (string str)
{
  std::string::size_type index = str.find ('{');
  if (index == string::npos)
    return true;
  int depth;
  for (depth = 1, index ++;  depth > 0 && index < str.length();  index ++)
    if (str[index] == '{')
      ++ depth;
    else if (str[index] == '}')
      -- depth;
  return depth == 0;
}

static int count_depth (const string &str, int count)
{
  //cerr << "count_depth (" << str << ", " << count << ")" << endl;
  std::string::size_type index = 0;
  if (count == 0)
    index = str.find ('{');
  while (index < str.length())
    {
      if (str[index] == '{')
	++ count;
      else if (str[index] == '}')
	-- count;
      //cerr << "    After char #" << index << ", count is " << count << endl;
      ++ index;
    }
  //cerr << "returning " << count << endl;
  return count;
}

static void handle_includes (const vector<string> &in_data, const string &filename, vector<string> &out_data, GeasInterface *gi)
{
  string line, tok;
  std::string::size_type tok_start, tok_end;
  for (uint ln = 0; ln < in_data.size(); ln ++)
    {
      line = in_data[ln];
      tok = first_token (line, tok_start, tok_end);
      if (tok == "!include")
	{
	  tok = next_token (line, tok_start, tok_end);
	  if (!is_param(tok))
	    {
	      gi->debug_print ("Expected parameter after !include");
	      continue;
	    }
	  //handle_includes (split_lines (gi->get_file (param_contents (tok))), out_data, gi);
	  string newname = gi->absolute_name (param_contents(tok), filename);
	  handle_includes (split_lines (gi->get_file (newname)), newname, out_data, gi);
	}
      else if (tok == "!QDK")
	{
	  while (ln < in_data.size() && 
		 first_token (in_data[ln], tok_start, tok_end) != "!end")
	    ++ ln;
	}
      else
	out_data.push_back (line);
    }
}

bool preprocess (vector<string> v, const string &fname, vector<string> &rv,
		 GeasInterface *gi)
{
  //cerr << "Before preprocessing:\n" << v << "\n\n" << endl;
  /*
    cerr << "Before preprocessing:\n";
  for (uint i = 0; i < v.size(); i ++)
    cerr << i << ": " << v[i] << "\n";
  cerr << "\n\n";
  */

  // TODO: Is it "!=" or "<>" or both, and if both, which has priority?
  static string comps[][2] = 
    { { "<>", "!=;" },  { "!=", "!=;" },  { "<=", "lt=;" },  { ">=", "gt=;" }, 
      { "<",  "lt;" },  { ">",  "gt;" },  { "=",  "" } };

  std::string::size_type tok_start, tok_end;
  string tok;

  // preprocessing step 0:
  // Loop through the lines.  Replace !include with appropriate text
  
  vector<string> v2;
  handle_includes (v, fname, v2, gi);
  v.clear();

  map <string, vector<string> > addtos;
  for (uint line = 0; line < v2.size(); line ++)
    {
      //cerr << "Line #" << line << ", looking for addtos: " << v2[line] << endl;
      tok = first_token (v2[line], tok_start, tok_end);
      if (tok == "!addto")
	{
	  tok = next_token (v2[line], tok_start, tok_end);
	  if (!(tok == "game" || tok == "synonyms" || tok == "type"))
	    {
	      gi->debug_print ("Error: Had addto for '" + tok + "'.");
	      continue;
	    }
	  if (tok == "type")
	    {
	      string tmp = next_token (v2[line], tok_start, tok_end);
	      if (!(tmp == "<default>" || tmp == "<defaultroom>"))
		{
		  gi->debug_print ("Error: Bad addto '" + v2[line] + "'\n");
		  continue;
		}
	      tok = tok + " " + tmp;
	    }
	  ++ line; // skip !addto
	  while (line < v2.size() && 
 		 first_token (v2[line], tok_start, tok_end) != "!end")
	    addtos[tok].push_back (v2[line ++]);
	}
    }
  for (uint line = 0; line < v2.size(); line ++)
    {
      tok = first_token (v2[line], tok_start, tok_end);
      if (tok == "!addto")
	{
	  while (line < v2.size() && 
		 first_token (v2[line], tok_start, tok_end) != "!end")
	    line ++;
	}
      else
	{
	  v.push_back (v2[line]);
	  if (tok == "define")
	    {
	      // TODO: What if there's a !addto for a block other than
	      // game, synonyms, default, defaultroom?
	      //
	      // Also, do the !addto'ed lines go at the front or end?
	      tok = next_token (v2[line], tok_start, tok_end);
	      if (tok == "type")
		tok = tok + " " + next_token (v2[line], tok_start, tok_end);

	      if (addtos.find(tok) != addtos.end())
		{
		  vector<string> &lines = addtos[tok];
		  for (uint line2 = 0; line2 < lines.size(); line2 ++)
		    v.push_back (lines[line2]);
		  addtos.erase(tok);
		}
	    }
	}
    }
  //cerr << "Done looking for addtos" << endl;
  v2.clear();

  for (map<string, vector<string> >::iterator i = addtos.begin();
       i != addtos.end(); i ++)
    {
      v.push_back ("define " + i->first);
      for (uint j = 0; j < i->second.size(); j ++)
	v.push_back (i->second[j]);
      v.push_back ("end define");
    }
  /*
  if (addtos.find("<default>") != addtos.end())
    {
      vector<string> &lines = addtos ["<default>"];
      v.push_back ("define type <default>");
      for (uint i = 0; i < lines.size(); i ++)
	v.push_back (lines[i]);
      v.push_back ("end define");
    }

  if (addtos.find("<defaultroom>") != addtos.end())
    {
      vector<string> &lines = addtos ["<defaultroom>"];
      v.push_back ("define type <defaultroom>");
      for (uint i = 0; i < lines.size(); i ++)
	v.push_back (lines[i]);
      v.push_back ("end define");
    }
  */
  /*
  cerr << "Done special-pushing <default> and <defaultroom>\n";
  cerr << "After includes & addtos:\n";
  for (uint i = 0; i < v.size(); i ++)
    cerr << i << ": " << v[i] << "\n";
  cerr << "\n\n";
  */

  // Preprocessing step 1:
  // Loop through the lines.  Look for "if/and/or (.. <.. )" or the like
  // If there is such a pair, convert the second to "if/and/or is <..;lt;..>"

  for (uint line = 0; line < v.size(); line ++)
    {
      tok_end = 0;
      while (tok_end < v[line].length()) 
	{
	  tok = next_token (v[line], tok_start, tok_end, false);
	  if (tok == "if" || tok == "repeat" || tok == "until" || 
	      tok == "and" || tok == "or")
	    {
	      tok = next_token (v[line], tok_start, tok_end, true);
	      //cerr << "Checking for comparison {" << tok << "}\n";
	      if (tok.length() > 2 && tok[0] == '(' && 
		  tok [tok.length() - 1] == ')')
		{
		  //cerr << "   IT IS!\n";
		  tok = tok.substr (1, tok.length() - 2);
		  string str = v[line];
		  std::string::size_type cmp_start;
		  for (uint cmp = 0; cmp < ARRAYSIZE(comps); cmp ++)
		    if ((cmp_start = tok.find(comps[cmp][0])) != string::npos)
		      {
			std::string::size_type cmp_end = cmp_start + comps[cmp][0].length();
			//cerr << "Changed str from {" << str << "} to {";
			str = str.substr(0, tok_start) + 
			  "is <" + trim (tok.substr(0, cmp_start)) + ";" + 
			  comps[cmp][1] + 
			  trim (tok.substr(cmp_end)) + ">" + 
			    str.substr(tok_end);
			//cerr << str << "}\n";
			cmp = ARRAYSIZE(comps);
			v[line] = str;
			tok_end = tok_start; // old value of tok_end invalid
		      }
		}
	    }
	}
    }
  //cerr << "Done with pass 1!" << endl;

  // Pass 2:  Extract comments from non-text blocks
  bool in_text_block = false;
  for (uint line = 0; line < v.size(); line ++)
    {
      //cerr << "Checking line '" << v[line] << "' for comments\n"; 
      if (!in_text_block && is_start_textmode (v[line]))
	in_text_block = true;
      else if (in_text_block && is_end_define (v[line]))
	in_text_block = false;
      else if (!in_text_block)
	{
	  //cerr << "  checking...\n";
	  std::string::size_type start_ch = 0, end_ch = 0;
	  while (start_ch < v[line].length())
	    if (next_token (v[line], start_ch, end_ch)[0] == '\'')
	      {
		v[line] = v[line].substr (0, start_ch);
		//cerr << "  abbreviating to '" << v[line] << "'\n";
		break;
	      }
	}
    }
  //cerr << "Done with pass 2!" << endl;

  /* There should be a pass 2.5: check that lbraces count equals
   * rbrace count, but I'm skipping that
   */

  // Pass 3: Deinline braces
  in_text_block = false;
  int int_proc_count = 0;
  for (uint line = 0; line < v.size(); line ++)
    {
      //cerr << "Pass 3, line #" << line << endl;
      string str = v[line];
      if (!in_text_block && is_start_textmode (str))
	in_text_block = true;
      else if (in_text_block && is_end_define (str))
	in_text_block = false;
      else if (!is_balanced (str))
	{
	  //cerr << "...Special line!" << endl;
	  std::string::size_type init_size = v.size();
	  v.push_back ("define procedure <!intproc" + 
		       string_int(++int_proc_count) + ">");
	  //cerr << "Pushing back on v: '" << v[v.size()-1] << "'" << endl;


	  std::string::size_type tmp_index = str.find ('{');
	  v2.push_back (trim (str.substr (0, tmp_index)) + 
			" do <!intproc" + string_int (int_proc_count) + "> ");
	  //cerr << "Done with '" << v2[v2.size()-1] << "'" << endl;

	  {
	    /*
	    string tmp_str = trim (str.substr (tmp_index + 1));
	    if (tmp_str != "")
	      {
		v.push_back (tmp_str);
		cerr << "Pushing back on v: '" << v[v.size()-1] << "'" << endl;
	      }
	    */
	    v.push_back (str.substr (tmp_index + 1));
	    //cerr << "Pushing back on v: '" << v[v.size()-1] << "'" << endl;
	  }

	  int count = count_depth (str, 0);
	  while (++ line < init_size && count != 0)
	    {
	      str = v[line];
	      count = count_depth (str, count);
	      if (count != 0)
		{
		  /*
		  str = trim(str);
		  if (str != "")
		    {
		      v.push_back (str);
		      cerr << "Pushing back on v: '" << str << "'" << endl;
		    }
		  */
		  v.push_back (str);
		  //cerr << "Pushing back on v: '" << str << "'" << endl;
		}
	    }
	  if (count != 0)
	    {
	      report_error ("Braces Unbalanced");
	      return false;
	    }
	  tmp_index = str.rfind ('}');
	  {
	    /*
	    string tmp2 = trim (str.substr (0, tmp_index));
	    if (tmp2 != "")
	      v.push_back (tmp2);
	    */
	    v.push_back (str.substr (0, tmp_index));
	    //cerr << "Pushing back on v: '" << v[v.size()-1] << "'" << endl;
	  }

	  v.push_back ("end define");
	  //cerr << "Pushing back on v: '" << v[v.size()-1] << "'" << endl;
	  //cerr << "Done with special line" << endl;
	  line --;
	  continue;
	  // The continue is to avoid the v2.push_back(...);
	  // this block pushes stuff onto v2 on its own.
	}
      //cerr << "Done with '" << str << "'" << endl;
      v2.push_back (str);
    }
  //cerr << "Done with pass 3!" << endl;

  /* Pass 4:  trim lines, drop blank lines, combine elses */
  
  in_text_block = false;
  int_proc_count = 0;
  for (uint line = 0; line < v2.size(); line ++)
    {
      string str = v2[line];
      //cerr << "Pass 4, line #" << line << ", " << in_text_block << ": '" << str << "'\n";
      if (!in_text_block && is_start_textmode (str))
	in_text_block = true;
      else if (in_text_block && is_end_define (str))
	in_text_block = false;
      else if (rv.size() > 0 && !in_text_block && get_token (str) == "else")
	{
	  rv[rv.size() - 1] = rv[rv.size() - 1] + " " + trim (str);
	  //cerr << "  Replacing else: " << rv[rv.size() - 1] << "\n";
	  continue;
	}
      if (!in_text_block)
	str = trim (str);
      if (in_text_block || str != "")
	rv.push_back (str);
      //if (rv.size() > 0)
      //  cerr << "  Result: " << rv[rv.size() - 1] << "\n";
    }

  /*
  cerr << "At end of procedure, v == " << v << "\n";
  cerr << "and v2 == " << v2 << "\n";
  cerr << "and rv == " << rv << "\n";
  */
  //rv = v2;

  /*
  cerr << "After all preprocessing\n";
  for (uint i = 0; i < rv.size(); i ++)
    cerr << i << ": " << rv[i] << "\n";
  cerr << "\n\n";
  */

  return true;
  //return v2;
}


void show_find (string s, char ch)
{
  cerr << "Finding '" << ch << "' in '" << s << "': " << s.find(ch)+1 << endl;
}

void show_trim (string s)
{
  cerr << "Trimming '" << s << "': spaces (" << trim (s)
       << "), underscores (" << trim (s, TRIM_UNDERSCORE)
       << "), braces (" << trim (s, TRIM_BRACE) << ").\n";
  
  //cerr << "Trimming '" << s << "': '" << trim (s) << "'\n";
}

template<class T> vector<T> &operator<< (vector<T> &v, T val) 
{
  v.push_back (val);
  return v;
}

template<class T> class makevector { 
  vector<T> dat;
public:
  makevector<T> &operator << (T it) { dat.push_back(it); return *this; }
  operator vector<T>() { return dat; }
};

vector <string> split (string s, char ch) {
  std::string::size_type i = 0, j;
  vector<string> rv;
  do
    {
      //cerr << "split (" << s << "): i == " << i << ", j == " << j << endl;
      j = s.find (ch, i);
      if (i != j)
	rv.push_back (s.substr (i, j-i));
      i = j + 1;
    }
  while (j < s.length());

  //cerr << rv << endl;
  return rv;
}

