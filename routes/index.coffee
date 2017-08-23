image = require './image'
file  = require './file'
cache = require '../middleware/cache'

exports.init = (app) ->

	# app.all '/*', (req, res, next) ->
	# 	res.header("Access-Control-Allow-Origin", "*")
	# 	res.header("Access-Control-Allow-Headers", "_authTokenId, _authTokenNs, content-type")
	# 	next()

	# IMAGE

	app.get '/rest/image/frame/:width/:height/:background/:namespace/:preprocess?/:document/:recordId/:field/:key', image.restCompatibilityFrame

	app.get '/rest/image/convert/:keys/:namespace/*', cache, image.restConvert

	app.get '/rest/image/:type/:width/:height/:namespace/:preprocess?/:document/:recordId/:field/:key', cache, image.restCompatibility

	app.get '/rest/image/:namespace/*', cache, image.restImage

	# FILE

	app.post '/rest/file/upload/:namespace/:accessId/:metaDocumentId/:recordId/:fieldName', file.restUpload

	app.post '/rest/file/uploadrtc/:namespace/:accessId/:metaDocumentId/:recordId/:fieldName', file.restUploadWebRTC

	app.post '/rest/file/move/:namespace/:accessId/:metaDocumentId/:recordId/:fieldName/:filePath', file.restMove

	app.del '/rest/file/delete/:namespace/:accessId/:metaDocumentId/:recordId/:fieldName/:fileName', file.restDelete

	app.get '/rest/file/download/:namespace/:metaDocumentId/:recordId/:fieldName/:fileName', cache, file.restDownload

	app.get '/rest/file/preview/:namespace/:metaDocumentId/:recordId/:fieldName/:fileName', cache, file.restPreview
