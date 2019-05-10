description 'vrp_vendas'

ui_page "nui/index.html"

files {
	"nui/index.html",
  "nui/ui.js"
}

client_script {
  '@vrp/lib/utils.lua',
  'client.lua',
}

server_script {
  '@vrp/lib/utils.lua',
  'server.lua'
}