describe "dropdownUserDirective", () ->
    scope = compile = provide = null
    mockTgAuth = null
    mockTgConfig = null
    mockTgLocation = null
    mockTgNavUrls = null
    mockTgFeedbackService = null
    template = "<div tg-dropdown-user></div>"

    createDirective = () ->
        elm = compile(template)(scope)
        return elm

    _mockTranslateFilter = () ->
        mockTranslateFilter = (value) ->
            return value
        provide.value "translateFilter", mockTranslateFilter

    _mockTgAuth = () ->
        mockTgAuth = {
            userData: Immutable.fromJS({id: 66})
            logout: sinon.stub()
        }
        provide.value "$tgAuth", mockTgAuth

    _mockTgConfig = () ->
        mockTgConfig = {
            get: sinon.stub()
        }
        provide.value "$tgConfig", mockTgConfig

    _mockTgLocation = () ->
        mockTgLocation = {
            path: sinon.stub()
        }
        provide.value "$tgLocation", mockTgLocation

    _mockTgNavUrls = () ->
        mockTgNavUrls = {
            resolve: sinon.stub()
        }
        provide.value "$tgNavUrls", mockTgNavUrls

    _mockTgFeedbackService = () ->
        mockTgFeedbackService = {
            sendFeedback: sinon.stub()
        }
        provide.value "tgFeedbackService", mockTgFeedbackService

    _mocks = () ->
        module ($provide) ->
            provide = $provide
            _mockTranslateFilter()
            _mockTgAuth()
            _mockTgConfig()
            _mockTgLocation()
            _mockTgNavUrls()
            _mockTgFeedbackService()
            return null

    beforeEach ->
        module "templates"
        module "taigaNavigationBar"

        _mocks()

        inject ($rootScope, $compile) ->
            scope = $rootScope.$new()
            compile = $compile

    it "dropdown user directive scope content", () ->
        mockTgConfig.get.withArgs("feedbackEnabled").returns(true)
        elm = createDirective()
        scope.$apply()

        vm = elm.isolateScope().vm
        expect(vm.user.get("id")).to.be.equal(66)
        expect(vm.isFeedbackEnabled).to.be.equal(true)

    it "dropdown user log out", () ->
        mockTgNavUrls.resolve.withArgs("login").returns("/login")
        elm = createDirective()
        scope.$apply()
        vm = elm.isolateScope().vm
        expect(mockTgAuth.logout.callCount).to.be.equal(0)
        expect(mockTgLocation.path.callCount).to.be.equal(0)
        vm.logout()
        expect(mockTgAuth.logout.callCount).to.be.equal(1)
        expect(mockTgLocation.path.callCount).to.be.equal(1)
        expect(mockTgLocation.path.calledWith("/login")).to.be.true

    it "dropdown user send feedback", () ->
        elm = createDirective()
        scope.$apply()
        vm = elm.isolateScope().vm
        expect(mockTgFeedbackService.sendFeedback.callCount).to.be.equal(0)
        vm.sendFeedback()
        expect(mockTgFeedbackService.sendFeedback.callCount).to.be.equal(1)
