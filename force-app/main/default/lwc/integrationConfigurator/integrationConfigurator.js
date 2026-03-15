import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getInitialData from "@salesforce/apex/UIF_AdminUIController.getInitialData";
import saveConfigDeploy from "@salesforce/apex/UIF_AdminUIController.saveConfigDeploy";

export default class IntegrationConfigurator extends LightningElement {
  @track currentView = 1; // 1 = List, 2 = Form, 3 = Mappings
  @track isLoading = false;

  @track configurations = [];
  @track sfObjectOptions = [];
  @track authOptionsPlain = [];

  @track draftConfig = {};
  @track selectedConfigName = "";
  @track selectedSourceObject = "";

  // Picker state
  @track isSfObjectPickerOpen = false;
  @track pickerSearchTerm = "";

  connectedCallback() {
    this.loadData();
  }

  loadData() {
    this.isLoading = true;
    getInitialData()
      .then((result) => {
        this.configurations = result.configurations.map((c) => ({
          ...c,
          statusClass: c.isActive ? "status-active" : "status-inactive"
        }));
        this.sfObjectOptions = result.sfObjectOptions;
        this.authOptionsPlain = result.authOptions;
      })
      .catch((error) => this.showToast("Error", error.body?.message, "error"))
      .finally(() => {
        this.isLoading = false;
      });
  }

  get isViewList() {
    return this.currentView === 1;
  }
  get isViewForm() {
    return this.currentView === 2;
  }
  get isViewMappings() {
    return this.currentView === 3;
  }
  get isEmptyState() {
    return this.configurations.length === 0;
  }
  get showBackButton() {
    return this.currentView > 1;
  }
  get showNewButton() {
    return this.currentView === 1;
  }
  get isEditMode() {
    return !!this.draftConfig.id;
  }
  get formTitle() {
    return this.isEditMode ? "Edit Configuration" : "New Configuration";
  }

  // Draft properties
  get isOutbound() {
    return this.draftConfig.direction === "Outbound";
  }
  get isInbound() {
    return this.draftConfig.direction === "Inbound";
  }
  get isBoth() {
    return this.draftConfig.direction === "Both";
  }

  get authOptions() {
    return this.authOptionsPlain.map((opt) => ({
      ...opt,
      selected: this.draftConfig.authConfig === opt.value
    }));
  }

  // Picker Logic
  get sfObjectDisplayValue() {
    const val = this.draftConfig.sourceObject;
    if (!val) return "Select SF Object Name";
    const opt = this.sfObjectOptions.find((o) => o.value === val);
    return opt ? opt.label : val;
  }
  get sfObjectDisplayClass() {
    return this.draftConfig.sourceObject
      ? "field-picker-display-text"
      : "field-picker-placeholder-text";
  }
  get filteredSfObjectOptions() {
    if (!this.pickerSearchTerm) return this.sfObjectOptions;
    const term = this.pickerSearchTerm.toLowerCase();
    return this.sfObjectOptions.filter((o) =>
      o.label.toLowerCase().includes(term)
    );
  }

  toggleSfObjectPicker(e) {
    e.stopPropagation();
    this.isSfObjectPickerOpen = !this.isSfObjectPickerOpen;
    this.pickerSearchTerm = "";
  }
  handlePickerSearch(e) {
    this.pickerSearchTerm = e.target.value;
  }
  handleSfObjectSelect(e) {
    this.draftConfig.sourceObject = e.currentTarget.dataset.value;
    this.isSfObjectPickerOpen = false;
  }
  handleInnerClick() {
    this._isInnerClick = true;
  }

  renderedCallback() {
    if (!this._clickBound) {
      this._clickBound = true;
      document.addEventListener("mousedown", () => {
        if (this._isInnerClick) {
          this._isInnerClick = false;
          return;
        }
        this.isSfObjectPickerOpen = false;
      });
    }
  }

  // Form Interactions
  handleNew() {
    this.draftConfig = { direction: "Outbound", isActive: true };
    this.currentView = 2;
  }
  handleEditConfig(e) {
    const configId = e.currentTarget.dataset.id;
    const conf = this.configurations.find((c) => c.id === configId);
    this.draftConfig = { ...conf };
    this.currentView = 2;
  }
  handleConfigChange(e) {
    const name = e.target.name;
    const val =
      e.target.type === "checkbox" ? e.target.checked : e.target.value;
    this.draftConfig[name] = val;
  }
  handleCancelConfig() {
    this.currentView = 1;
  }

  handleSaveConfig() {
    if (
      !this.draftConfig.developerName ||
      !this.draftConfig.sourceObject ||
      !this.draftConfig.externalSystem
    ) {
      this.showToast("Validation", "Missing required fields", "warning");
      return;
    }

    this.isLoading = true;
    saveConfigDeploy({ configData: this.draftConfig })
      .then((jobId) => {
        this.showToast("Deploying", "Deployment queued: " + jobId, "info");
        this.currentView = 1;
        // In a real scenario, you'd poll Metadata.Operations for jobId status.
        // For demo, we just reload data after a small delay.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => this.loadData(), 2000);
      })
      .catch((error) => {
        this.showToast("Error", error.body?.message, "error");
        this.isLoading = false;
      });
  }

  handleViewMappings(e) {
    const configId = e.currentTarget.dataset.id;
    const conf = this.configurations.find((c) => c.id === configId);
    this.selectedConfigName = conf.developerName;
    this.selectedSourceObject = conf.sourceObject;
    this.currentView = 3;
  }

  handleBack() {
    this.currentView = 1;
    this.loadData();
  }

  showToast(title, msg, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message: msg, variant }));
  }
}
