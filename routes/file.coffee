gm   = require 'gm'
fs   = require 'fs'
path = require 'path'
mm   = require 'mmmagic'
crypto = require 'crypto'
magic   = new mm.Magic(mm.MAGIC_MIME_TYPE)
Domain  = require 'domain'
mkdirp  = require 'mkdirp'
Busboy  = require 'busboy'
util    = require 'util'
request = require 'request'
bugsnag = require 'bugsnag'
exec    = require('child_process').exec



updataDB = (params) ->
	result =
		success: true
		etag: params.etag
		key: params.key
		kind: params.contentType
		size: params.bufferLength
		name: params.filename

	result.key = result.key.split('/')
	result.key = result.key.map (item) ->
		return encodeURIComponent item
	result.key = result.key.join('/')

	cookie = params.req.get 'cookie'
	if not cookie and params.req.headers._authtokenid and params.req.headers._authtokenns
		cookie = "_authTokenId=#{params.req.headers._authtokenid};_authTokenNs=#{params.req.headers._authtokenns}"

	host = process.env.KONECTY_HOST or params.req.headers.origin
	host = host.replace(/\/$/, '')
	if not /^https?:\/\/.+/.test(host)
		host = 'http://' + host

	requestParams =
		url: "#{host}/rest/file2/#{params.documentId}/#{params.recordId}/#{encodeURI(params.fieldName)}/"
		headers:
			cookie: cookie
		json: true
		body: result


	request.post requestParams, (err, response, body) ->
		result.coreResponse = body
		if not err? and body?
			result._id = body._id
			result._updatedAt = body._updatedAt
		else
			result = body
			console.log err
			bugsnag.notify err
		params.callback err, result


saveToDisk = (params) ->
	filePath = path.join process.env.USE_LOCAL_DISK_PATH, params.bucket, params.key
	mkdirp path.dirname(filePath), (err) ->
		if err?
			bugsnag.notify err
			console.error new Date, 'Error creating directories', path.dirname(filePath), err
			return params.res.send 500

		fs.writeFile filePath, params.buffer, (err) ->
			if err?
				bugsnag.notify err
				console.error new Date, 'Error writing', filePath, err

			updataDB(params)


processAndSaveToDisk = (req, res, bucket, file, buf, filename, callback) ->
	magic.detect buf, (err, contentType) ->
		if err?
			bugsnag.notify err
			console.log err

		processIfImage = (buf, mime, callback) ->
			if /image/.test(mime) is false or mime is 'image/vnd.dwg'
				return callback buf

			image = gm buf

			if req.params.metaDocumentId in [ 'WebElement', 'BlogPost' ] or bucket in ['konecty.cfl', 'konecty.gruposavar']
				image.quality 100
				image.define 'jpeg:preserve-settings'
			else
				image.autoOrient()
				image.quality 80

			image.resize 2880, 1800, '>'

			image.toBuffer (err, buffer) ->
				if err?
					bugsnag.notify err
					console.trace err
					return callback buf
				callback buffer


		processIfImage buf, contentType, (buf) ->

			md5 = crypto.createHash 'md5'
			md5.update buf
			etag = md5.digest 'hex'

			saveToDisk
				bucket: bucket
				key: path.join file, filename
				buffer: buf
				bufferLength: buf.length
				contentType: contentType
				etag: etag
				res: res
				filename: filename
				documentId: req.params.metaDocumentId
				recordId: req.params.recordId
				fieldName: req.params.fieldName
				namespace: req.params.namespace
				callback: callback
				req: req


exports.restUpload = (req, res, next) ->
	bucket = "konecty.#{req.params.namespace}"
	file = "#{req.params.metaDocumentId}/#{req.params.recordId}/#{req.params.fieldName}"


	processUrlencoded = ->
		bufs = []
		req.on 'data', (data) ->
			bufs.push data

		req.on 'end', ->
			buf = Buffer.concat bufs
			processAndSaveToDisk req, res, bucket, file, buf, decodeURI(req.get('x-file-name')), (err, result) ->
				if err?
					return next err
				res.send 200, result


	processMultipart = ->
		partsCount = 0
		busboy = new Busboy headers: req.headers

		busboy.on 'file', (fieldname, part, filename, encoding) ->
			# console.log filename, arguments
			partsCount = partsCount + 1

			bufs = []
			part.on 'data', (data) ->
				bufs.push data

			part.on 'end', () ->
				buf = Buffer.concat bufs

				if encoding is '7bit'
					encoding = 'binary'

				buf = new Buffer buf.toString('utf8'), encoding

				processAndSaveToDisk req, res, bucket, file, buf, decodeURI(filename), (err, result) ->
					if err?
						return next err

					partsCount = partsCount - 1
					if partsCount is 0
						res.send 200, result


		busboy.on 'error', ->
			console.log arguments

		busboy.on 'end', ->
			if partsCount is 0
				res.send 400

		req.pipe busboy

	if req.get('content-type') is 'application/x-www-form-urlencoded'
		processUrlencoded()
	else
		processMultipart()


exports.restMove = (req, res, next) ->
	bucket = "konecty.#{req.params.namespace}"
	file = "#{req.params.metaDocumentId}/#{req.params.recordId}/#{req.params.fieldName}"


	if /^https?:\/\/.+/.test(req.params.filePath)
		request {url: encodeURI(req.params.filePath), encoding: null}, (err, im, buffer) ->
			if err?
				return res.send err
			processAndSaveToDisk req, res, bucket, file, buffer, req.params.filePath.split('/').pop(), (err, result) ->
					if err?
						return next err
					res.send 200, result
	else
		fs.readFile req.params.filePath, (err, buffer) ->
			if err?
				return res.send err
			processAndSaveToDisk req, res, bucket, file, buffer, req.params.filePath.split('/').pop(), (err, result) ->
					if err?
						return next err
					res.send 200, result


exports.restUploadWebRTC = (req, res, next) ->
	bucket = "konecty.#{req.params.namespace}"
	fileInitialPath = "#{req.params.metaDocumentId}/#{req.params.recordId}/#{req.params.fieldName}"

	merge = (res, files) ->
		filename = files.video.name.split('.')[0] + '-merged.webm'
		audioFile = path.join process.env.USE_LOCAL_DISK_PATH, bucket, fileInitialPath, files.audio.name
		videoFile = path.join process.env.USE_LOCAL_DISK_PATH, bucket, fileInitialPath, files.video.name
		mergedFile = path.join process.env.USE_LOCAL_DISK_PATH, bucket, fileInitialPath, filename
		console.log mergedFile

		command = "ffmpeg -i " + videoFile + " -i " + audioFile + " -map 0:0 -map 1:0 " + mergedFile

		exec command, (error, stdout, stderr) ->
			# if stdout then console.log stdout
			if stderr then console.log stderr

			if error?
				console.log('exec error: ' + error)
				res.send(404)

			else
				exec "ffmpeg -itsoffset -0 -i #{mergedFile} -vcodec mjpeg -vframes 1 -an -f rawvideo #{mergedFile.replace('.webm', '')}.jpg", (error, stdout, stderr) ->
					if stderr then console.log stderr
					if error?
						console.log('exec error: ' + error)

				fs.unlink audioFile
				fs.unlink videoFile
				fs.stat mergedFile, (err, stat) ->
					updataDB
						etag: Math.random().toString(36).slice(2)
						key: path.join fileInitialPath, filename
						contentType: 'video/webm'
						bufferLength: stat?.size
						filename: filename
						documentId: req.params.metaDocumentId
						recordId: req.params.recordId
						fieldName: req.params.fieldName
						req: req
						callback: (err, result) ->
							res.send(err || result)


	_upload = (file, cb) ->
		filePath = path.join process.env.USE_LOCAL_DISK_PATH, bucket, fileInitialPath, file.name

		mkdirp path.dirname(filePath), (err) ->
			if err?
				bugsnag.notify err
				console.error new Date, 'Error creating directories', path.dirname(filePath), err
				return params.res.send 500

			file.contents = file.contents.split(',').pop()

			fileBuffer = new Buffer file.contents, "base64"

			fs.writeFile filePath, fileBuffer, cb


	postData = ''
	req.on 'data', (postDataChunk) ->
		postData += postDataChunk;

	req.on 'end', ->
		files = JSON.parse postData

		_upload files.audio, ->
			_upload files.video, ->
				merge res, files


exports.restDownload = (req, res, next) ->
	res.set 'Content-Disposition', "attachment; filename=#{req.params.fileName}"

	exports.restPreview req, res, next


exports.restPreview = (req, res, next) ->
	if req.params.recordId?
		Key = "#{req.params.metaDocumentId}/#{req.params.recordId}/#{req.params.fieldName}/#{req.params.fileName}"
	else
		Key = "#{req.params.metaDocumentId}/#{req.params.fieldName}/#{req.params.fileName}"

	params =
		Bucket: "konecty.#{req.params.namespace}"
		Key: Key

	domain = Domain.create()
	domain.on 'error', (err) ->
		if err?.statusCode?
			return res.send err.statusCode
		res.send 500, err

	domain.run ->
		file = path.join process.env.USE_LOCAL_DISK_PATH, params.Bucket, params.Key
		fs.createReadStream(file).pipe(res)


exports.restDelete = (req, res, next) ->
	params =
		Bucket: "konecty.#{req.params.namespace}"
		Key: "#{req.params.metaDocumentId}/#{req.params.recordId}/#{req.params.fieldName}/#{decodeURIComponent(req.params.fileName)}"

	host = process.env.KONECTY_HOST or req.headers.origin
	host = host.replace(/\/$/, '')
	if not /^https?:\/\/.+/.test(host)
		host = 'http://' + host

	requestParams =
		url: "#{host}/rest/file2/#{req.params.metaDocumentId}/#{req.params.recordId}/#{req.params.fieldName}/#{encodeURI(req.params.fileName)}"
		headers:
			cookie: req.get 'cookie'
		json: true

	request.del requestParams, (err, response, body) ->
		if err?
			bugsnag.notify err
			console.error new Date, 'Error deleting file into core', response?.statusCode, requestParams.url, err, body
			return res.send 500

		if response.statusCode isnt 200
			return res.send response.statusCode, body

		filePath = path.join process.env.USE_LOCAL_DISK_PATH, params.Bucket, params.Key
		fs.unlink filePath, (err) ->
			if err?
				bugsnag.notify err
				console.error new Date, 'Error deleting ', filePath, err

			res.send response.statusCode, body
