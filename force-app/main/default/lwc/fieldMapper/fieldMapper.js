import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getConfigDetailData from '@salesforce/apex/UIF_AdminUIController.getConfigDetailData';
import getLookupTargetFields from '@salesforce/apex/UIF_AdminUIController.getLookupTargetFields';
import saveMappingDeploy from '@salesforce/apex/UIF_AdminUIController.saveMappingDeploy';

export default class FieldMapper extends LightningElement {
    @api configName; // Passed from parent
    @api objectName; 
    
    @track isLoading = false;
    @track currentView = 1; // 1 = list, 2 = form
    
    @track mappings = [];
    @track sfFieldOptions = [];
    @track transformOptionsPlain = [];
    
    // Config properties for fields
    @track sfObjectName = ''; // Deprecated, using objectName from parent
    
    @track draftMapping = {};

    // Picker states
    @track isSfFieldPickerOpen = false;
    @track sfFieldSearchTerm = '';
    @track enrichedSfFieldOptions = [];
    @track dropdownStyle = '';
    @track flyoutStyle = '';

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        this.isLoading = true;
        this.fetchDataFromApex();
    }

    fetchDataFromApex() {
        getConfigDetailData({ configName: this.configName, sfObjectName: this.objectName })
            .then(res => {
                console.log('mappings ' +res.mappings);
                this.mappings = res.mappings;
                this.sfFieldOptions = res.sfFieldOptions;
                this.transformOptionsPlain = res.transformOptions;
                this.syncEnrichedOptions();
            })
            .catch(err => {
                // If it fails due to blank sObject, we'd add an apex fetch here.
                // Assuming it works or returns empty field list. (Needs the config's source_object__c).
                // It's a demo so we'll catch and toast.
                this.showToast('Error', err.body?.message, 'error');
            })
            .finally(() => this.isLoading = false);
    }

    get isListView() { return this.currentView === 1; }
    get isFormView() { return this.currentView === 2; }
    get isEmptyState() { return this.mappings.length === 0; }
    get isEditMode() { return !!this.draftMapping.id; }
    get formTitle() { return this.isEditMode ? 'Edit Mapping' : 'New Mapping'; }
    
    get isArrayMapping() { return this.draftMapping.isArray; }
    get scalarTabClass() { return !this.draftMapping.isArray ? 'toggle-tab active' : 'toggle-tab'; }
    get arrayTabClass() { return this.draftMapping.isArray ? 'toggle-tab active' : 'toggle-tab'; }

    get dataTypeOptions() {
        const types = ['String', 'Integer', 'Decimal', 'Boolean', 'Date', 'DateTime', 'Id'];
        return types.map(t => ({ label: t, value: t, selected: this.draftMapping.dataType === t }));
    }

    get transformOptions() {
        return this.transformOptionsPlain.map(opt => ({
            ...opt,
            selected: this.draftMapping.transformRule === opt.value
        }));
    }

    // --- Cascading Field Picker Logic ---
    syncEnrichedOptions() {
        const term = this.sfFieldSearchTerm.toLowerCase();
        let sourceList = this.sfFieldOptions;
        if (term) {
            sourceList = sourceList.filter(o => o.label.toLowerCase().includes(term) || o.value.toLowerCase().includes(term));
        }
        
        this.enrichedSfFieldOptions = sourceList.map(opt => {
            const existing = this.enrichedSfFieldOptions.find(e => e.value === opt.value);
            return {
                ...opt,
                isExpanded: existing ? existing.isExpanded : false,
                isLoadingTarget: existing ? existing.isLoadingTarget : false,
                targetFields: existing ? existing.targetFields : [],
                targetObjectLabel: existing ? existing.targetObjectLabel : 'Target Object'
            };
        });
    }

    get sfFieldDisplayValue() { return this.draftMapping.sourceField || 'Select Salesforce Field'; }
    get sfFieldDisplayClass() { return this.draftMapping.sourceField ? 'field-picker-display-text' : 'field-picker-placeholder-text'; }

    toggleSfFieldPicker(e) {
        e.stopPropagation();
        this.isSfFieldPickerOpen = !this.isSfFieldPickerOpen;
        if (this.isSfFieldPickerOpen) {
            this.sfFieldSearchTerm = '';
            this.syncEnrichedOptions();
            // Position
            const rect = e.currentTarget.getBoundingClientRect();
            this.dropdownStyle = `top: ${rect.bottom + 4}px; left: ${rect.left}px; width: ${rect.width}px;`;
        }
    }

    handleSfFieldSearch(e) {
        this.sfFieldSearchTerm = e.target.value;
        this.syncEnrichedOptions();
    }

    handleSfFieldSelect(e) {
        this.draftMapping.sourceField = e.currentTarget.dataset.value;
        this.isSfFieldPickerOpen = false;
    }

    handleExpandFlyout(e) {
        e.stopPropagation();
        const fieldValue = e.currentTarget.dataset.value;
        
        // Find positions
        const listEl = this.template.querySelector('.field-picker-list');
        const triggerEl = e.currentTarget.closest('.field-picker-item-row');
        let flyoutTop = 0; let flyoutLeft = '100%';
        if (listEl && triggerEl) {
            // Standard bounding logic
        }
        this.flyoutStyle = `top: 0px; left: 100%;`;

        this.enrichedSfFieldOptions = this.enrichedSfFieldOptions.map(opt => {
            if (opt.value === fieldValue) {
                if (opt.isExpanded) return { ...opt, isExpanded: false };
                
                const alreadyLoaded = opt.targetFields && opt.targetFields.length > 0;
                if (!alreadyLoaded) this.fetchLookupFields(opt.value);

                return { ...opt, isExpanded: true, isLoadingTarget: !alreadyLoaded, targetObjectLabel: alreadyLoaded ? opt.targetObjectLabel : 'Loading...' };
            }
            return { ...opt, isExpanded: false };
        });
    }

    fetchLookupFields(fieldName) {
        getLookupTargetFields({ objectName: this.objectName, fieldName: fieldName })
            .then(res => {
                this.enrichedSfFieldOptions = this.enrichedSfFieldOptions.map(o => {
                    if (o.value === fieldName) {
                        return { ...o, isLoadingTarget: false, targetFields: res, targetObjectLabel: 'Related Fields' };
                    }
                    return o;
                });
            })
            .catch(err => console.error(err));
    }

    handleFlyoutBack(e) {
        e.stopPropagation();
        const fieldValue = e.currentTarget.dataset.value;
        this.enrichedSfFieldOptions = this.enrichedSfFieldOptions.map(opt => {
            if (opt.value === fieldValue) return { ...opt, isExpanded: false };
            return opt;
        });
    }

    handleTargetFieldSelect(e) {
        e.stopPropagation();
        this.draftMapping.sourceField = e.currentTarget.dataset.value;
        this.isSfFieldPickerOpen = false;
    }

    handleInnerClick() { this._innerClick = true; }
    stopPropagation(e) { e.stopPropagation(); }
    
    renderedCallback() {
        if (!this._bound) {
            this._bound = true;
            document.addEventListener('mousedown', () => {
                if (this._innerClick) { this._innerClick = false; return; }
                this.isSfFieldPickerOpen = false;
            });
        }
    }

    // --- Form Actions ---
    handleMappingTypeToggle(e) {
        this.draftMapping.isArray = e.currentTarget.dataset.type === 'array';
    }

    handleMappingChange(e) {
        if (e.target.type === 'checkbox') this.draftMapping[e.target.name] = e.target.checked;
        else this.draftMapping[e.target.name] = e.target.value;
    }

    handleNewMapping() {
        this.draftMapping = { dataType: 'String', isArray: false };
        this.currentView = 2;
    }

    handleEditMapping(e) {
        const mid = e.currentTarget.dataset.id;
        this.draftMapping = { ...this.mappings.find(m => m.id === mid) };
        this.currentView = 2;
    }

    handleCancelMapping() { this.currentView = 1; }

    handleSaveMapping() {
        if (!this.draftMapping.developerName || !this.draftMapping.sourceField || !this.draftMapping.targetField) {
            this.showToast('Validation Error', 'Missing required fields', 'warning');
            return;
        }

        this.draftMapping.configDevName = this.configName;
        this.isLoading = true;
        saveMappingDeploy({ mappingData: this.draftMapping })
            .then(jobId => {
                this.showToast('Deployment Queued', 'Job Id: ' + jobId, 'info');
                this.currentView = 1;
                setTimeout(() => this.loadData(), 2000); // Simulate refresh
            })
            .catch(err => {
                this.showToast('Error', err.body?.message, 'error');
                this.isLoading = false;
            });
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    showToast(title, msg, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: msg, variant }));
    }
}
