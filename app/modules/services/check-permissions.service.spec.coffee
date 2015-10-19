describe "tgCheckPermissionsService", ->
    checkPermissionsService = provide = null
    mocks = {}

    _mockProjectService = () ->
        mocks.projectService = {
            project: sinon.stub()
        }

        provide.value "tgProjectService", mocks.projectService

    _inject = () ->
        inject (_tgCheckPermissionsService_) ->
            checkPermissionsService = _tgCheckPermissionsService_

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockProjectService()

            return null

    beforeEach ->
        module "taigaCommon"
        _mocks()
        _inject()

    it "the user has perms", () ->
        mocks.projectService.project = Immutable.fromJS({
            my_permissions: ['add_us']
        })

        perm = checkPermissionsService.check('add_us')

        expect(perm).to.be.true

    it "the user hasn't perms", () ->
        mocks.projectService.project = Immutable.fromJS({
            my_permissions: []
        })

        perm = checkPermissionsService.check('add_us')

        expect(perm).to.be.false
