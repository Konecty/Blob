request = require('supertest')
request = request('http://localhost:3000')


describe 'Upload file', ->
	it 'respond with 200', (done) ->
		request.post('/rest/file/upload/test/metaDocumentId/accessId/recordId/fieldName')
			.attach('file2', './public/origin.png')
			.attach('file', './public/origin.png')
			# .expect('Content-Type', /json/)
			.expect(200, done)



describe 'Get images using compatibility mode', ->
	urls = [
		'/rest/image/outer/75/75/test/metaDocumentId/recordId/fieldName/origin.png'
		'/rest/image/crop/75/75/test/metaDocumentId/recordId/fieldName/origin.png'
		'/rest/image/frame/75/75/gray/test/metaDocumentId/recordId/fieldName/origin.png'
		'/rest/image/inner/75/75/test/metaDocumentId/recordId/fieldName/origin.png'
		'/rest/image/force/75/75/test/metaDocumentId/recordId/fieldName/origin.png'
	]

	for url in urls
		do (url) ->
			it 'respond with json', (done) ->
				request.get(url)
					# .expect('Content-Type', /image/)
					.expect(200, done)


describe 'Get images using new convert mode', () ->
	urls = [
		'/rest/image/test/metaDocumentId/recordId/fieldName/origin.png'
		'/rest/image/convert/resize:75x75x^/test/metaDocumentId/recordId/fieldName/origin.png'
		'/rest/image/convert/resize:75x75x^,crop:75x75/test/metaDocumentId/recordId/fieldName/origin.png'
		'/rest/image/convert/resize:75x75,extent:75x75,background:gray/test/metaDocumentId/recordId/fieldName/origin.png'
		'/rest/image/convert/resize:75x75,extent:75x75/test/metaDocumentId/recordId/fieldName/origin.png'
		'/rest/image/convert/resize:75x75x!/test/metaDocumentId/recordId/fieldName/origin.png'
	]

	for url in urls
		do (url) ->
			it 'respond with json', (done) ->
				request.get(url)
					# .expect('Content-Type', /image/)
					.expect(200, done)


describe 'Download uploaded file', () ->
	it 'respond with file', (done) ->
		request.get('/rest/file/download/test/metaDocumentId/recordId/fieldName/origin.png')
			# .expect('Content-Type', 'image/png')
			.expect(200, done)


describe 'Preview uploaded file', () ->
	it 'respond with file', (done) ->
		request.get('/rest/file/preview/test/metaDocumentId/recordId/fieldName/origin.png')
			# .expect('Content-Type', 'image/png')
			.expect(200, done)


describe 'Delete uploaded file', () ->
	it 'respond with file', (done) ->
		request.del('/rest/file/delete/test/metaDocumentId/accessId/recordId/fieldName/origin.png')
			# .expect('Content-Type', 'image/png')
			.expect(200, done)


describe 'Try to get deleted file', () ->
	it 'respond with file', (done) ->
		request.get('/rest/file/download/test/metaDocumentId/recordId/fieldName/origin.png')
			# .expect('Content-Type', 'image/png')
			.expect(404, done)

