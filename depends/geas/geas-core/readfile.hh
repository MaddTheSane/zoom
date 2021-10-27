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

#ifndef __readfile_hh
#define __readfile_hh

#include "geasfile.hh"
#include "general.hh"

#include <vector>
#include <string>
#include <ostream>
#include <iostream>

std::vector<std::string> tokenize (const std::string &s);
std::string next_token (const std::string &full, std::string::size_type &tok_start, std::string::size_type &tok_end, bool cvt_paren = false);
std::string first_token (const std::string &s, std::string::size_type &t_start, std::string::size_type &t_end);
std::string nth_token (const std::string &s, int n);
std::string get_token (const std::string &s, bool cvt_paren = false);
bool find_token (const std::string &s, const std::string &tok, std::string::size_type &tok_start, std::string::size_type &tok_end, bool cvt_paren = false);
GeasFile read_geas_file (GeasInterface *, const std::string &);

enum trim_modes { TRIM_SPACES, TRIM_UNDERSCORE, TRIM_BRACE };
std::string trim (const std::string &, trim_modes mode = TRIM_SPACES);

//std::ostream &operator<< (std::ostream &o, const std::vector<std::string> &v);


#endif
