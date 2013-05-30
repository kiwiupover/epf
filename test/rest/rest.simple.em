describe "rest", ->

  adapter = null

  beforeEach ->
    require('./_shared').setupRest.apply(this)
    adapter = @adapter

  context 'simple model', ->

    beforeEach ->
      class @Post extends Ep.Model
        title: Ep.attr('string')
      @App.Post = @Post

      @container.register 'model:post', @Post, instantiate: false


    it 'loads', ->
      @adapter.r['GET:/posts/1'] = posts: {id: 1, title: 'mvcc ftw'}

      session = @adapter.newSession()

      ajaxCalls = @adapter.h
      session.load(@Post, 1).then (post) ->
        expect(post.id).to.eq("1")
        expect(post.title).to.eq('mvcc ftw')
        expect(ajaxCalls).to.eql(['GET:/posts/1'])


    it 'loads when plural specified', ->
      @RestAdapter.configure 'plurals',
        post: 'postsandthings'
      # Re-instantiate since mappings are reified
      @adapter = @container.lookup('adapter:main')
      @adapter.r['GET:/postsandthings/1'] = postsandthings: {id: 1, title: 'mvcc ftw'}

      session = @adapter.newSession()

      ajaxCalls = @adapter.h
      session.load(@Post, 1).then (post) ->
        expect(post.id).to.eq("1")
        expect(post.title).to.eq('mvcc ftw')
        expect(ajaxCalls).to.eql(['GET:/postsandthings/1'])


    it 'saves', ->
      @adapter.r['POST:/posts'] = -> posts: {client_id: post.clientId, id: 1, title: 'mvcc ftw'}

      session = @adapter.newSession()

      post = session.create('post')
      post.title = 'mvcc ftw'

      ajaxCalls = @adapter.h
      session.flush().then ->
        expect(post.id).to.eq("1")
        expect(post.title).to.eq('mvcc ftw')
        expect(ajaxCalls).to.eql(['POST:/posts'])


    it 'updates', ->
      @adapter.r['PUT:/posts/1'] = -> posts: {client_id: post.clientId, id: 1, title: 'updated'}

      @adapter.loaded(@Post.create(id: "1", title: 'test'))

      session = @adapter.newSession()
      post = null
      ajaxCalls = @adapter.h
      session.load('post', 1).then (post) ->
        expect(post.title).to.eq('test')
        post.title = 'updated'
        session.flush().then ->
          expect(post.title).to.eq('updated')
          expect(ajaxCalls).to.eql(['PUT:/posts/1'])


    it 'deletes', ->
      @adapter.r['DELETE:/posts/1'] = {}

      @adapter.loaded(@Post.create(id: "1", title: 'test'))

      session = @adapter.newSession()

      ajaxCalls = @adapter.h
      session.load('post', 1).then (post) ->
        expect(post.id).to.eq("1")
        expect(post.title).to.eq('test')
        session.deleteModel(post)
        session.flush().then ->
          expect(post.isDeleted).to.be.true
          expect(ajaxCalls).to.eql(['DELETE:/posts/1'])


    it 'refreshes', ->
      @adapter.loaded(@Post.create(id: "1", title: 'test'))
      @adapter.r['GET:/posts/1'] = posts: {id: 1, title: 'something new'}

      session = @adapter.newSession()

      ajaxCalls = @adapter.h
      session.load(@Post, 1).then (post) ->
        expect(post.title).to.eq('test')
        expect(ajaxCalls).to.eql([])
        session.refresh(post).then (post) ->
          expect(post.title).to.eq('something new')
          expect(ajaxCalls).to.eql(['GET:/posts/1'])


    it 'finds', ->
      @adapter.r['GET:/posts'] = (url, type, hash) ->
        expect(hash.data).to.eql({q: "aardvarks"})
        posts: [{id: 1, title: 'aardvarks explained'}, {id: 2, title: 'aardvarks in depth'}]

      session = @adapter.newSession()

      ajaxCalls = @adapter.h
      session.find('post', {q: 'aardvarks'}).then (models) ->
        expect(models.length).to.eq(2)
        expect(ajaxCalls).to.eql(['GET:/posts'])


    it 'handles errors on update', ->
      @adapter.r['PUT:/posts/1'] = ->
        throw responseText: JSON.stringify(errors: {title: 'title is too short'})

      @adapter.loaded(@Post.create(id: "1", title: 'test'))

      session = @adapter.newSession()
      post = null
      ajaxCalls = @adapter.h
      session.load('post', 1).then (post) ->
        expect(post.title).to.eq('test')
        post.title = ''
        session.flush().then null, (errors) ->
          expect(post.title).to.eq('')
          expect(post.errors).to.eql({title: 'title is too short'})
          expect(ajaxCalls).to.eql(['PUT:/posts/1'])


    it 'loads then updates', ->
      @adapter.r['GET:/posts/1'] = posts: {id: 1, title: 'mvcc ftw'}
      @adapter.r['PUT:/posts/1'] = posts: {id: 1, title: 'no more fsm'}

      session = @adapter.newSession()

      ajaxCalls = @adapter.h
      session.load(@Post, 1).then (post) ->
        expect(post.id).to.eq("1")
        expect(post.title).to.eq('mvcc ftw')
        expect(ajaxCalls).to.eql(['GET:/posts/1'])

        post.title = 'no more fsm'
        session.flush().then ->
          expect(ajaxCalls).to.eql(['GET:/posts/1', 'PUT:/posts/1'])
          expect(post.title).to.eq('no more fsm')