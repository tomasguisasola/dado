#!/usr/local/bin/lua

local dado = require"dado"
local dbname = arg[1] or "luasql-test"
local user = arg[2] or "postgres"
local pass = arg[3]
local driver = arg[4]

local db = dado.connect (dbname, user, pass, driver)
assert (type(db) == "table", "Nao consegui criar a conexao")
assert (type(db.conn) == "userdata")
assert (string.find (tostring(db.conn), "connection"))
local mt = getmetatable(db)
assert (type(mt) == "table")
assert (type(mt.__index) == "table")
assert (mt.__index.select)
io.write"."

-- Teste de encerramento e reabertura da conexao
local db2 = dado.connect (dbname, user, pass, driver)
assert (db.conn == db2.conn)
db:close()
assert (db.conn == nil)
db2 = dado.connect (dbname, user, pass, driver)
assert (db2.conn)
db = dado.connect (dbname, user, pass, driver)
io.write"."

-- Elimina a tabela de teste
db.conn:execute ("drop table tabela")
io.write"."

-- Criando a tabela de teste
assert (db:assertexec ([[
create table tabela (
	chave integer,
	campo1 varchar(10),
	campo2 varchar(10),
	ativo  boolean,
	data   date,
	primary key (chave)
)]]))
io.write"."

-- Dados para o teste
local dados = {
	{ campo1 = "val1", campo2 = "val21", ativo = true, },
	{ campo1 = "val2", campo2 = "val22", ativo = false, },
	{ campo1 = "val3", campo2 = "val32", ativo = true, },
}

-- Preenchendo a tabela
for indice, registro in ipairs(dados) do
	assert (false == pcall (db.insert, db, "tabela", registro))
	registro.chave = indice
    assert (1 == db:insert ("tabela", registro))
end
io.write"."

-- Consulta
local contador = 0
local select_iter, cur = db:select ("campo1, campo2", "tabela", "chave >= 1")
assert (type(select_iter) == "function")
assert (cur, "`select' didn't returned a cursor")
assert (tostring(cur):find"ursor", "`select' didn't returned a cursor object ("..tostring(cur)..")")
for campo1, campo2 in select_iter do
	contador = contador + 1
	assert (campo1 == dados[contador].campo1)
	assert (campo2 == dados[contador].campo2)
end
cur:close()
io.write"."

-- Consulta 2
local contador = #dados
local rs = {}
local select_iter, cur = db:select ("campo1, campo2", "tabela", "chave >= 1", "order by chave desc", rs)
assert (type(select_iter) == "function")
assert (cur, "`select' didn't returned a cursor")
assert (tostring(cur):find"ursor", "`select' didn't returned a cursor object ("..tostring(cur)..")")
for result in select_iter do
	assert (type(result) == "table", "`select' didn't returned a table")
	assert (result == rs, "`select' returned a different table!")
	assert (result.campo1 == dados[contador].campo1)
	assert (result.campo2 == dados[contador].campo2)
	contador = contador - 1
end
cur:close()
io.write"."

-- Consulta 3
local total = #dados
local rs = db:selectall ("campo1, campo2", "tabela", "chave >= 1", "order by chave desc")
assert (type(rs) == "table", "`selectall' didn't returned a table")
for i = 1, #rs do
	local linha = rs[i]
	assert (type(linha) == "table", "`selectall' didn't returned a table for row #"..i)
	local c = total+1 - i
	assert (linha.campo1 == dados[c].campo1)
	assert (linha.campo2 == dados[c].campo2)
end
io.write"."

-- Teste de valores especiais para datas
local n = #dados + 1
db:insert ("tabela", {
	campo1 = "val"..n,
	chave = n,
	data = "((CURRENT_TIMESTAMP))",
})
io.write"."

-- Redefinindo a `assertexec'
local log_table = {}
local lc = 0
local function log (s) lc = lc+1 log_table[lc] = s end
local old_assertexec = assert(dado.assertexec, "Cannot find function `assertexec'.  Maybe this is a version mistaken!")
dado.assertexec = function (self, stmt)
	log (stmt)
	return old_assertexec (self, stmt)
end
assert (log_table[1] == nil)
assert (db:select ("*", "tabela")())
assert (log_table[1] == "select * from tabela", ">>"..tostring(log_table[1]))
io.write"."

-- Wrapping an already opened connection
driver = driver or "postgres"
local luasql = require("luasql."..driver)
local env = luasql[driver]()
local conn = env:connect(dbname, user, pass)
local new_db = dado.wrap_connection(conn)
io.write"."

assert (type(new_db) == "table", "Couldn't create a connection")
assert (type(new_db.conn) == "userdata")
assert (string.find (tostring(new_db.conn), "connection"))
local mt = getmetatable(new_db)
assert (type(mt) == "table")
assert (type(mt.__index) == "table")
assert (mt.__index == dado)
io.write"."

new_db:close()
assert (new_db.conn == nil)
io.write"."

-- Protected transaction
assert (pcall (db.docommit) == false, ":docommit() should throw an error when called without any arguments")
assert (pcall (db.docommit, db) == false,
	":docommit() should throw an error when called without a function as its first argument")
assert (pcall (db.docommit, db, 1) == false,
	":docommit() should throw an error when called without a function as its first argument")
local ok, err = db:docommit (function (dbconn)
	dbconn:insert ("tabela", {
		campo1 = "committed",
		chave = n+1,
		data = "((CURRENT_TIMESTAMP))",
	})
end)
assert (ok == true, "Error while running the function inside a transaction: "..tostring(err))
local v, _ = db:select ("campo1, data", "tabela", "chave = "..(n+1))()
assert (v == "committed", "Could not insert a value through the function inside a connection")
io.write"."

local ok, err = db:docommit (function (dbconn)
	dbconn:insert ("tabela", {
		non_existant_column = 1,
	})
end)
assert (ok == false, "Error while running a wrong function inside a transaction: "..tostring(err))
io.write"."

local ok, _ = db:dorollback (function (dbconn)
	-- This key (chave) already exists, so this function should throw an error,
	-- despite it being run by :dorollback()
	dbconn:insert ("tabela", {
		campo1 = "second",
		chave = n+1,
		data = "((CURRENT_TIMESTAMP))",
	})
end)
assert (ok == false, ":dorollback() accepted a function that produced an error!")
io.write"."

local ok, err = db:dorollback (function (dbconn)
	dbconn:insert ("tabela", {
		campo1 = "second",
		chave = n+2,
		data = "((CURRENT_TIMESTAMP))",
	})
end)
assert (ok == true, "Error while running the function inside a transaction: "..tostring(err))
local v, _ = db:select ("campo1, data", "tabela", "chave = "..(n+2))()
-- The function executed correctly, but :dorollback() rolled back its effect
assert (v == nil, "Could insert a value through the function inside a rolled back connection")
io.write"."

print(' '..dado._VERSION.." Ok!")
